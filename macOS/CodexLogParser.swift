import Foundation

/// 解析 ~/.codex/sessions/**/*.jsonl（Codex CLI / Desktop 会话 rollout 日志）。
/// token_count 事件里的 total_token_usage 是累计值：
/// - 相邻事件做差得到逐事件用量，按天归档；
/// - 会话总量取最后一条累计值；
/// - rate_limits 快照即 ChatGPT 应用内的官方限额数据，取全局最新一条。
struct CodexLogParser {
    static let roots = [
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/archived_sessions"),
    ]

    private struct RateLimitCapture {
        var timestamp: Date
        var plan: String?
        var windows: [LimitWindow]
        var creditsBalance: String?
    }

    func parse(into builder: AggregateBuilder) {
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(AggregateBuilder.keepDays + 2) * 86400)
        var latestLimits: RateLimitCapture?

        for root in Self.roots {
            guard let enumerator = fm.enumerator(at: root,
                                                 includingPropertiesForKeys: [.contentModificationDateKey],
                                                 options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                if let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   mtime < cutoff { continue }
                parseFile(url, into: builder, latestLimits: &latestLimits)
            }
        }

        if let cap = latestLimits {
            builder.codexLimits = CodexLimits(plan: cap.plan,
                                              windows: cap.windows,
                                              creditsBalance: cap.creditsBalance,
                                              capturedAt: cap.timestamp)
        }
    }

    private func parseFile(_ url: URL, into builder: AggregateBuilder, latestLimits: inout RateLimitCapture?) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }

        var projectPath = ""
        var sessionID = url.deletingPathExtension().lastPathComponent
        var model: String?
        var prev = CumulativeTotals()
        var last = CumulativeTotals()
        var lastActivity: Date?
        var sessionCost = 0.0

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let payload = obj["payload"] as? [String: Any] else { continue }
            let type = obj["type"] as? String
            let timestamp = (obj["timestamp"] as? String).flatMap(Fmt.parseISO)

            switch type {
            case "session_meta":
                if let cwd = payload["cwd"] as? String { projectPath = cwd }
                if let id = payload["id"] as? String { sessionID = id }
                if let m = payload["model"] as? String { model = m }
            case "turn_context":
                if let m = payload["model"] as? String { model = m }
                if projectPath.isEmpty, let cwd = payload["cwd"] as? String { projectPath = cwd }
            case "event_msg":
                guard payload["type"] as? String == "token_count" else { continue }
                if let info = payload["info"] as? [String: Any],
                   let totals = info["total_token_usage"] as? [String: Any] {
                    let current = CumulativeTotals(totals)
                    let delta = current.delta(since: prev)
                    prev = current
                    last = current
                    if !delta.isEmpty {
                        let date = timestamp ?? Date()
                        if date > (lastActivity ?? .distantPast) { lastActivity = date }
                        var tally = delta
                        tally.costUSD = Pricing.shared.cost(model: model ?? "gpt-5", tally: tally)
                        sessionCost += tally.costUSD
                        builder.add(day: Fmt.dayKey(date), source: .codex, model: model ?? "gpt-5", tally: tally)
                    }
                }
                if let rl = payload["rate_limits"] as? [String: Any],
                   let capture = Self.capture(rateLimits: rl, at: timestamp ?? Date()) {
                    if capture.timestamp > (latestLimits?.timestamp ?? .distantPast) {
                        latestLimits = capture
                    }
                }
            default:
                break
            }
        }

        var sessionTally = last.tally
        sessionTally.costUSD = sessionCost
        guard !sessionTally.isEmpty else { return }
        builder.addSession(SessionStat(sessionID: sessionID,
                                       project: (projectPath as NSString).lastPathComponent,
                                       source: .codex,
                                       title: nil,
                                       tally: sessionTally,
                                       lastActivity: lastActivity),
                           projectPath: projectPath)
    }

    // MARK: 累计值

    private struct CumulativeTotals {
        var input = 0
        var cached = 0
        var cacheWrite = 0
        var output = 0

        init() {}

        init(_ dict: [String: Any]) {
            input = dict["input_tokens"] as? Int ?? 0
            cached = dict["cached_input_tokens"] as? Int ?? 0
            cacheWrite = dict["cache_write_input_tokens"] as? Int ?? 0
            output = dict["output_tokens"] as? Int ?? 0
        }

        /// OpenAI 的 input_tokens 含缓存部分；拆开记账。
        var tally: TokenTally {
            var t = TokenTally()
            t.input = max(input - cached, 0)
            t.cacheRead = cached
            t.cacheWrite = cacheWrite
            t.output = output
            return t
        }

        func delta(since prev: CumulativeTotals) -> TokenTally {
            var t = TokenTally()
            let dInput = max(input - prev.input, 0)
            let dCached = max(cached - prev.cached, 0)
            t.input = max(dInput - dCached, 0)
            t.cacheRead = dCached
            t.cacheWrite = max(cacheWrite - prev.cacheWrite, 0)
            t.output = max(output - prev.output, 0)
            return t
        }
    }

    // MARK: 官方限额快照

    private static func capture(rateLimits: [String: Any], at timestamp: Date) -> RateLimitCapture? {
        // 新版带 limit_id（codex / premium），只关心 codex 主限额
        if let limitID = rateLimits["limit_id"] as? String, limitID != "codex" { return nil }

        var windows: [LimitWindow] = []
        for (key, name) in [("primary", "主限额"), ("secondary", "次限额")] {
            guard let w = rateLimits[key] as? [String: Any],
                  let used = w["used_percent"] as? Double else { continue }
            let minutes = w["window_minutes"] as? Int
            var resetsAt: Date?
            if let epoch = w["resets_at"] as? Double {
                resetsAt = Date(timeIntervalSince1970: epoch)
            } else if let inSeconds = w["resets_in_seconds"] as? Double {
                resetsAt = timestamp.addingTimeInterval(inSeconds)
            }
            windows.append(LimitWindow(key: key,
                                       label: Self.windowLabel(minutes: minutes, fallback: name),
                                       utilization: used,
                                       resetsAt: resetsAt,
                                       windowMinutes: minutes))
        }
        guard !windows.isEmpty else { return nil }

        var balance: String?
        if let credits = rateLimits["credits"] as? [String: Any] {
            if credits["unlimited"] as? Bool == true {
                balance = "不限量"
            } else if let b = credits["balance"] as? String, b != "0" {
                balance = b
            }
        }
        return RateLimitCapture(timestamp: timestamp,
                                plan: rateLimits["plan_type"] as? String,
                                windows: windows,
                                creditsBalance: balance)
    }

    static func windowLabel(minutes: Int?, fallback: String) -> String {
        guard let minutes else { return fallback }
        switch minutes {
        case 0..<120: return "\(minutes) 分钟窗口"
        case 120..<2880: return "\(minutes / 60) 小时窗口"
        case 9000...11000: return "周限额"
        default: return "\(minutes / 1440) 天窗口"
        }
    }
}
