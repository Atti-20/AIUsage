import Foundation

/// 解析 ~/.claude/projects/**/*.jsonl（Claude Code 会话日志）。
/// 每条 assistant 消息带 message.usage；按 message.id + requestId 全局去重
/// （会话分叉/续写会把同一条消息复制进多个文件）。
struct ClaudeLogParser {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    func parse(into builder: AggregateBuilder) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: Self.root,
                                             includingPropertiesForKeys: [.contentModificationDateKey],
                                             options: [.skipsHiddenFiles]) else { return }
        let cutoff = Date().addingTimeInterval(-Double(AggregateBuilder.keepDays + 2) * 86400)
        var seen = Set<String>()

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if let mtime = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               mtime < cutoff { continue }
            parseFile(url, into: builder, seen: &seen)
        }
    }

    private func parseFile(_ url: URL, into builder: AggregateBuilder, seen: inout Set<String>) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }

        var sessionTally = TokenTally()
        var projectPath = ""
        var title: String?
        var lastActivity: Date?

        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            let type = obj["type"] as? String

            if projectPath.isEmpty, let cwd = obj["cwd"] as? String { projectPath = cwd }

            if type == "summary", let s = obj["summary"] as? String, !s.isEmpty {
                title = s
                continue
            }
            guard type == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }

            let model = message["model"] as? String ?? "unknown"
            if model == "<synthetic>" { continue }

            // 全局去重
            let msgID = message["id"] as? String ?? ""
            let reqID = obj["requestId"] as? String ?? ""
            if !msgID.isEmpty || !reqID.isEmpty {
                let key = msgID + "|" + reqID
                if seen.contains(key) { continue }
                seen.insert(key)
            }

            var tally = TokenTally()
            tally.input = usage["input_tokens"] as? Int ?? 0
            tally.output = usage["output_tokens"] as? Int ?? 0
            tally.cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
            tally.cacheWrite = usage["cache_creation_input_tokens"] as? Int ?? 0
            if let cost = obj["costUSD"] as? Double {
                tally.costUSD = cost
            } else {
                tally.costUSD = Pricing.shared.cost(model: model, tally: tally)
            }

            let date = (obj["timestamp"] as? String).flatMap(Fmt.parseISO) ?? Date()
            if date > (lastActivity ?? .distantPast) { lastActivity = date }

            builder.add(day: Fmt.dayKey(date), source: .claude, model: model, tally: tally)
            sessionTally.add(tally)
        }

        guard !sessionTally.isEmpty else { return }
        let sessionID = url.deletingPathExtension().lastPathComponent
        builder.addSession(SessionStat(sessionID: sessionID,
                                       project: (projectPath as NSString).lastPathComponent,
                                       source: .claude,
                                       title: title,
                                       tally: sessionTally,
                                       lastActivity: lastActivity),
                           projectPath: projectPath)
    }
}
