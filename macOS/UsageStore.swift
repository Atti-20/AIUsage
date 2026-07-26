import Foundation
import SwiftUI

/// macOS 端数据中枢：定时解析本地日志 + 拉取官方限额与重置动态，
/// 汇总成 UsageSnapshot 发布给界面，并写入 iCloud 供 iOS 端读取。
@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published var serverRunning = false

    @AppStorage("refreshMinutes") var refreshMinutes: Int = 5

    private var timer: Timer?
    private var started = false

    func startIfNeeded() {
        guard !started else { return }
        started = true
        SnapshotServer.shared.start()
        refresh()
        scheduleTimer()
    }

    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(max(refreshMinutes, 1) * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var menuBarTitle: String {
        guard let snapshot else { return "AI" }
        return Fmt.usd(snapshot.today.totalCost)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        SnapshotServer.shared.start()   // 端口曾被占用时自动重试绑定

        Task.detached(priority: .userInitiated) { [weak self] in
            await Pricing.shared.loadRemoteIfNeeded()

            async let claudeLimits = ClaudeOAuthClient.fetch()
            async let resets = (try? CodexResetsClient.fetch()) ?? []

            let builder = AggregateBuilder()
            ClaudeLogParser().parse(into: builder)
            CodexLogParser().parse(into: builder)

            let snapshot = builder.build(claudeLimits: await claudeLimits, resets: await resets)
            if let data = try? SyncStore.encoder.encode(snapshot) {
                SnapshotServer.shared.update(data)
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.snapshot = snapshot
                self.serverRunning = SnapshotServer.shared.isRunning
                self.isRefreshing = false
            }
        }
    }
}
