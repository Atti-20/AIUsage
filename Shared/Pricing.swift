import Foundation

/// 模型单价，单位：美元 / 每百万 token。
struct ModelPrice: Codable {
    var input: Double
    var output: Double
    var cacheRead: Double
    var cacheWrite: Double

    init(input: Double, output: Double, cacheRead: Double = 0, cacheWrite: Double = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
    }
}

/// 定价：内置表兜底，可用 LiteLLM 公开价格表在线刷新（缓存 24 小时）。
final class Pricing: @unchecked Sendable {
    static let shared = Pricing()

    private let lock = NSLock()
    private var remote: [String: ModelPrice] = [:]
    private var remoteLoadedAt: Date?

    /// 按顺序前缀/包含匹配；靠前优先。
    static let builtin: [(pattern: String, price: ModelPrice)] = [
        // Anthropic
        ("claude-fable-5", ModelPrice(input: 10, output: 50, cacheRead: 1, cacheWrite: 12.5)),
        ("claude-opus-5", ModelPrice(input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25)),
        ("claude-opus-4-5", ModelPrice(input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25)),
        ("claude-opus-4-1", ModelPrice(input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75)),
        ("claude-opus-4", ModelPrice(input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75)),
        ("claude-sonnet-5", ModelPrice(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75)),
        ("claude-sonnet-4", ModelPrice(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75)),
        ("claude-haiku-4-5", ModelPrice(input: 1, output: 5, cacheRead: 0.1, cacheWrite: 1.25)),
        ("claude-3-5-haiku", ModelPrice(input: 0.8, output: 4, cacheRead: 0.08, cacheWrite: 1)),
        ("claude", ModelPrice(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75)),
        // OpenAI / Codex
        ("gpt-5-mini", ModelPrice(input: 0.25, output: 2, cacheRead: 0.025)),
        ("gpt-5-nano", ModelPrice(input: 0.05, output: 0.4, cacheRead: 0.005)),
        ("codex-mini", ModelPrice(input: 1.5, output: 6, cacheRead: 0.375)),
        ("gpt-5", ModelPrice(input: 1.25, output: 10, cacheRead: 0.125)),
        ("gpt", ModelPrice(input: 1.25, output: 10, cacheRead: 0.125)),
    ]

    func price(for model: String) -> ModelPrice {
        let m = model.lowercased()
        lock.lock()
        let remoteCopy = remote
        lock.unlock()

        if let p = remoteCopy[m] { return p }
        // 远程键与模型名互相包含时取最长匹配键
        var best: (key: String, price: ModelPrice)?
        for (k, p) in remoteCopy where m.contains(k) || k.contains(m) {
            if best == nil || k.count > best!.key.count { best = (k, p) }
        }
        if let best { return best.price }
        for (pattern, p) in Self.builtin where m.contains(pattern) {
            return p
        }
        return ModelPrice(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75)
    }

    func cost(model: String, tally: TokenTally) -> Double {
        let p = price(for: model)
        return (Double(tally.input) * p.input
                + Double(tally.output) * p.output
                + Double(tally.cacheRead) * p.cacheRead
                + Double(tally.cacheWrite) * p.cacheWrite) / 1_000_000
    }

    // MARK: 远程价格表（LiteLLM）

    private static let remoteURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!

    private static var cacheFile: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AIUsage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("litellm-prices.json")
    }

    private func lastLoadedAt() -> Date? {
        lock.lock()
        defer { lock.unlock() }
        return remoteLoadedAt
    }

    func loadRemoteIfNeeded() async {
        if let loadedAt = lastLoadedAt(), Date().timeIntervalSince(loadedAt) < 3600 { return }

        // 先用磁盘缓存（24 小时内有效）
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Self.cacheFile.path),
           let mtime = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(mtime) < 86400,
           let data = try? Data(contentsOf: Self.cacheFile) {
            apply(data: data)
            return
        }

        var request = URLRequest(url: Self.remoteURL)
        request.timeoutInterval = 20
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            // 网络失败时退回旧缓存
            if let data = try? Data(contentsOf: Self.cacheFile) { apply(data: data) }
            return
        }
        try? data.write(to: Self.cacheFile)
        apply(data: data)
    }

    private func apply(data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var table: [String: ModelPrice] = [:]
        for (key, value) in root {
            let k = key.lowercased()
            guard let entry = value as? [String: Any],
                  let inCost = entry["input_cost_per_token"] as? Double,
                  let outCost = entry["output_cost_per_token"] as? Double else { continue }
            let cacheRead = entry["cache_read_input_token_cost"] as? Double ?? 0
            let cacheWrite = entry["cache_creation_input_token_cost"] as? Double ?? 0
            // 去掉 provider 前缀（如 "anthropic/claude-…"）
            let bare = k.components(separatedBy: "/").last ?? k
            table[bare] = ModelPrice(input: inCost * 1_000_000,
                                     output: outCost * 1_000_000,
                                     cacheRead: cacheRead * 1_000_000,
                                     cacheWrite: cacheWrite * 1_000_000)
        }
        guard !table.isEmpty else { return }
        lock.lock()
        remote = table
        remoteLoadedAt = Date()
        lock.unlock()
    }
}
