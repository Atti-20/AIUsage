import Foundation

// MARK: - 数据来源

enum UsageSource: String, Codable, CaseIterable, Identifiable {
    case claude
    case codex

    var id: String { rawValue }
    var displayName: String { self == .claude ? "Claude" : "Codex" }
}

// MARK: - Token 统计

/// input 为非缓存输入 token；缓存部分记在 cacheRead / cacheWrite。
struct TokenTally: Codable, Equatable {
    var input: Int = 0
    var output: Int = 0
    var cacheRead: Int = 0
    var cacheWrite: Int = 0
    var costUSD: Double = 0

    var totalTokens: Int { input + output + cacheRead + cacheWrite }
    var isEmpty: Bool { totalTokens == 0 }

    mutating func add(_ other: TokenTally) {
        input += other.input
        output += other.output
        cacheRead += other.cacheRead
        cacheWrite += other.cacheWrite
        costUSD += other.costUSD
    }

    static func + (l: TokenTally, r: TokenTally) -> TokenTally {
        var t = l
        t.add(r)
        return t
    }
}

// MARK: - 各维度统计

struct DailyStat: Codable, Identifiable {
    var day: String            // "yyyy-MM-dd"（本地时区）
    var claude: TokenTally = TokenTally()
    var codex: TokenTally = TokenTally()

    var id: String { day }
    var totalCost: Double { claude.costUSD + codex.costUSD }

    func tally(for source: UsageSource) -> TokenTally {
        source == .claude ? claude : codex
    }
}

struct ModelStat: Codable, Identifiable {
    var model: String
    var source: UsageSource
    var tally: TokenTally

    var id: String { "\(source.rawValue)|\(model)" }
}

struct ProjectStat: Codable, Identifiable {
    var name: String
    var path: String
    var source: UsageSource
    var tally: TokenTally
    var sessionCount: Int
    var lastActivity: Date?

    var id: String { "\(source.rawValue)|\(path)" }
}

struct SessionStat: Codable, Identifiable {
    var sessionID: String
    var project: String
    var source: UsageSource
    var title: String?
    var tally: TokenTally
    var lastActivity: Date?

    var id: String { "\(source.rawValue)|\(sessionID)" }
}

// MARK: - 官方限额

struct LimitWindow: Codable, Identifiable {
    var key: String            // five_hour / seven_day / primary / secondary …
    var label: String          // 展示名，如 "5 小时窗口"
    var utilization: Double    // 0–100
    var resetsAt: Date?
    var windowMinutes: Int?

    var id: String { key }
}

struct ClaudeLimits: Codable {
    var subscription: String?
    var windows: [LimitWindow] = []
    var fetchedAt: Date?
    var error: String?
}

struct CodexLimits: Codable {
    var plan: String?
    var windows: [LimitWindow] = []
    var creditsBalance: String?
    var capturedAt: Date?
}

// MARK: - codex-resets.com 重置事件

struct ResetEvent: Codable, Identifiable {
    var tweetID: String
    var tweetURL: String
    var text: String
    var announcedAt: Date

    var id: String { tweetID }

    enum CodingKeys: String, CodingKey {
        case tweetID = "tweet_id"
        case tweetURL = "tweet_url"
        case text
        case announcedAt = "announced_at"
    }
}

struct ResetStats {
    var count: Int
    var averageIntervalDays: Double?
    var longestIntervalDays: Double?
    var lastReset: Date?

    static func compute(from events: [ResetEvent]) -> ResetStats {
        let sorted = events.map(\.announcedAt).sorted()
        guard let last = sorted.last else {
            return ResetStats(count: 0, averageIntervalDays: nil, longestIntervalDays: nil, lastReset: nil)
        }
        var intervals: [TimeInterval] = []
        for i in 1..<sorted.count {
            intervals.append(sorted[i].timeIntervalSince(sorted[i - 1]))
        }
        let avg = intervals.isEmpty ? nil : intervals.reduce(0, +) / Double(intervals.count) / 86400
        let maxI = intervals.max().map { $0 / 86400 }
        return ResetStats(count: sorted.count, averageIntervalDays: avg, longestIntervalDays: maxI, lastReset: last)
    }
}

// MARK: - 同步快照（Mac 生成，经 iCloud 同步到 iOS / 小组件）

struct UsageSnapshot: Codable {
    var generatedAt: Date
    var deviceName: String
    var days: [DailyStat] = []            // 升序，最多 90 天
    var models: [ModelStat] = []
    var projects: [ProjectStat] = []
    var sessions: [SessionStat] = []
    var claudeLimits: ClaudeLimits?
    var codexLimits: CodexLimits?
    var resets: [ResetEvent] = []         // 降序（最新在前）

    // MARK: 便捷计算

    static var todayKey: String { Fmt.dayKey(Date()) }

    func day(_ key: String) -> DailyStat? {
        days.first { $0.day == key }
    }

    var today: DailyStat {
        day(Self.todayKey) ?? DailyStat(day: Self.todayKey)
    }

    var monthCost: Double {
        let prefix = String(Self.todayKey.prefix(7))
        return days.filter { $0.day.hasPrefix(prefix) }.reduce(0) { $0 + $1.totalCost }
    }

    var totalCost: Double {
        days.reduce(0) { $0 + $1.totalCost }
    }

    func recentDays(_ n: Int) -> [DailyStat] {
        Array(days.suffix(n))
    }

    func models(for source: UsageSource) -> [ModelStat] {
        models.filter { $0.source == source }.sorted { $0.tally.costUSD > $1.tally.costUSD }
    }

    func projects(for source: UsageSource?) -> [ProjectStat] {
        let list = source.map { s in projects.filter { $0.source == s } } ?? projects
        return list.sorted { $0.tally.costUSD > $1.tally.costUSD }
    }

    func sessions(for source: UsageSource?) -> [SessionStat] {
        let list = source.map { s in sessions.filter { $0.source == s } } ?? sessions
        return list.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    /// 全部限额窗口（带来源前缀标签），用于总览页的环形指示器。
    var allLimitWindows: [(source: UsageSource, window: LimitWindow)] {
        var out: [(UsageSource, LimitWindow)] = []
        for w in claudeLimits?.windows ?? [] { out.append((.claude, w)) }
        for w in codexLimits?.windows ?? [] { out.append((.codex, w)) }
        return out
    }
}
