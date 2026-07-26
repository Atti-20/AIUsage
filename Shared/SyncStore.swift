import Foundation

/// 快照的序列化与本地缓存。
/// Mac → iPhone 的传输走局域网（SnapshotServer / LANClient）；
/// iOS 端把最近一次拉到的快照存进 App Group，供离线查看和小组件读取。
enum SyncStore {
    static let appGroupID = "group.com.zhange.aiusage"

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: App Group 缓存（iOS App 与小组件共享）

    private static var appGroupFile: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshot.json")
    }

    static func writeAppGroupCache(_ snapshot: UsageSnapshot) {
        guard let url = appGroupFile, let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func readAppGroupCache() -> UsageSnapshot? {
        guard let url = appGroupFile, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }
}
