import Foundation

/// 汇总器：两个解析器把逐条用量灌进来，最后组装成 UsageSnapshot。
final class AggregateBuilder {
    private var perDay: [String: DailyStat] = [:]
    private var perModel: [String: ModelStat] = [:]
    private var perProject: [String: ProjectStat] = [:]
    private var sessions: [SessionStat] = []
    var codexLimits: CodexLimits?

    /// 只保留最近 N 天
    static let keepDays = 90

    private lazy var cutoffKey: String = {
        Fmt.dayKey(Date().addingTimeInterval(-Double(Self.keepDays) * 86400))
    }()

    func add(day: String, source: UsageSource, model: String, tally: TokenTally) {
        guard day >= cutoffKey else { return }
        var d = perDay[day] ?? DailyStat(day: day)
        if source == .claude { d.claude.add(tally) } else { d.codex.add(tally) }
        perDay[day] = d

        let mKey = "\(source.rawValue)|\(model)"
        var m = perModel[mKey] ?? ModelStat(model: model, source: source, tally: TokenTally())
        m.tally.add(tally)
        perModel[mKey] = m
    }

    func addSession(_ session: SessionStat, projectPath: String) {
        guard !session.tally.isEmpty else { return }
        sessions.append(session)

        let name = (projectPath as NSString).lastPathComponent
        let pKey = "\(session.source.rawValue)|\(projectPath)"
        var p = perProject[pKey] ?? ProjectStat(name: name.isEmpty ? "未知项目" : name,
                                                path: projectPath,
                                                source: session.source,
                                                tally: TokenTally(),
                                                sessionCount: 0,
                                                lastActivity: nil)
        p.tally.add(session.tally)
        p.sessionCount += 1
        if let a = session.lastActivity, a > (p.lastActivity ?? .distantPast) {
            p.lastActivity = a
        }
        perProject[pKey] = p
    }

    func build(claudeLimits: ClaudeLimits?, resets: [ResetEvent]) -> UsageSnapshot {
        var snapshot = UsageSnapshot(generatedAt: Date(), deviceName: Host.current().localizedName ?? "Mac")
        snapshot.days = perDay.values.sorted { $0.day < $1.day }
        snapshot.models = perModel.values.sorted { $0.tally.costUSD > $1.tally.costUSD }
        snapshot.projects = Array(perProject.values
            .sorted { $0.tally.costUSD > $1.tally.costUSD }
            .prefix(30))
        snapshot.sessions = Array(sessions
            .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
            .prefix(50))
        snapshot.claudeLimits = claudeLimits
        snapshot.codexLimits = codexLimits
        snapshot.resets = Array(resets.prefix(60))
        return snapshot
    }
}
