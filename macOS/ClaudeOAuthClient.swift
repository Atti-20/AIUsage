import Foundation

/// 读取 Claude Code 存在钥匙串里的 OAuth 令牌，
/// 调用官方 usage 接口拿 Claude 应用内的限额进度（5 小时窗口 / 周限额）。
/// 拿不到时返回带错误说明的空结果，界面回退到本地估算。
enum ClaudeOAuthClient {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch() async -> ClaudeLimits {
        guard let creds = readCredentials() else {
            return ClaudeLimits(subscription: nil, windows: [],
                                fetchedAt: Date(),
                                error: "未读取到 Claude Code 登录凭据：想显示 Claude 官方限额，在终端运行 claude 登录一次即可（本地用量统计不受影响）")
        }
        var request = URLRequest(url: usageURL)
        request.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return ClaudeLimits(subscription: creds.subscription, windows: [],
                                fetchedAt: Date(), error: "Claude 限额接口请求失败")
        }
        guard http.statusCode == 200 else {
            let hint = http.statusCode == 401
                ? "Claude 登录令牌已过期，在终端运行一次 claude 即可刷新"
                : "Claude 限额接口返回 \(http.statusCode)"
            return ClaudeLimits(subscription: creds.subscription, windows: [],
                                fetchedAt: Date(), error: hint)
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ClaudeLimits(subscription: creds.subscription, windows: [],
                                fetchedAt: Date(), error: "Claude 限额数据解析失败")
        }

        var windows: [LimitWindow] = []
        let known: [(String, String)] = [
            ("five_hour", "5 小时窗口"),
            ("seven_day", "周限额"),
            ("seven_day_sonnet", "Sonnet 周限额"),
            ("seven_day_opus", "Opus 周限额"),
        ]
        for (key, label) in known {
            guard let w = root[key] as? [String: Any], let win = window(from: w, key: key, label: label) else { continue }
            windows.append(win)
        }
        // 未知键兜底：任何带 utilization 的字典都展示
        for (key, value) in root {
            guard !known.contains(where: { $0.0 == key }),
                  let w = value as? [String: Any], w["utilization"] != nil,
                  let win = window(from: w, key: key, label: key) else { continue }
            windows.append(win)
        }

        return ClaudeLimits(subscription: creds.subscription, windows: windows,
                            fetchedAt: Date(), error: windows.isEmpty ? "接口未返回限额窗口" : nil)
    }

    private static func window(from dict: [String: Any], key: String, label: String) -> LimitWindow? {
        guard let raw = dict["utilization"] as? Double else { return nil }
        let percent = raw <= 1.0 ? raw * 100 : raw
        var resetsAt: Date?
        if let s = dict["resets_at"] as? String {
            resetsAt = Fmt.parseISO(s)
        } else if let epoch = dict["resets_at"] as? Double {
            resetsAt = Date(timeIntervalSince1970: epoch)
        }
        return LimitWindow(key: key, label: label, utilization: percent, resetsAt: resetsAt, windowMinutes: nil)
    }

    // MARK: 钥匙串

    private struct Credentials {
        var accessToken: String
        var subscription: String?
    }

    /// Claude Code 的凭据存在登录钥匙串条目 "Claude Code-credentials" 里。
    /// 首次读取时系统会弹窗询问是否允许，选"始终允许"即可。
    private static func readCredentials() -> Credentials? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        return Credentials(accessToken: token,
                           subscription: oauth["subscriptionType"] as? String)
    }
}
