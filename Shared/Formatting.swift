import Foundation

enum Fmt {
    // MARK: 日期

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .abbreviated
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func dayKeyToDate(_ key: String) -> Date {
        dayFormatter.date(from: key) ?? Date()
    }

    static func shortDay(_ key: String) -> String {
        shortDayFormatter.string(from: dayKeyToDate(key))
    }

    static func parseISO(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// "3小时12分后重置" / "2天3小时后重置" / "已到重置时间"
    static func countdown(to date: Date) -> String {
        let s = date.timeIntervalSinceNow
        if s <= 0 { return "已到重置时间" }
        let minutes = Int(s / 60)
        if minutes < 60 { return "\(minutes)分钟后重置" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)小时\(minutes % 60)分后重置" }
        return "\(hours / 24)天\(hours % 24)小时后重置"
    }

    static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: 数值

    static func usd(_ v: Double) -> String {
        if v >= 1000 { return String(format: "$%.0f", v) }
        if v >= 100 { return String(format: "$%.1f", v) }
        return String(format: "$%.2f", v)
    }

    static func tokens(_ n: Int) -> String {
        let v = Double(n)
        if v >= 1_000_000_000 { return String(format: "%.2fB", v / 1_000_000_000) }
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        return "\(n)"
    }

    static func percent(_ v: Double) -> String {
        String(format: "%.0f%%", v)
    }

    static func days(_ v: Double) -> String {
        String(format: "%.1f 天", v)
    }
}
