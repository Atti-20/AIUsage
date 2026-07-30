import SwiftUI
import WidgetKit

@main
struct AIUsageiOSApp: App {
    @StateObject private var store = IOSStore()

    var body: some Scene {
        WindowGroup {
            IOSRootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// iOS 端数据中枢：局域网发现 Mac 上的快照服务并拉取，
/// 成功后缓存到 App Group（离线可看 + 小组件读取）；
/// 全球重置预测另行在线拉取保证新鲜。
@MainActor
final class IOSStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isRefreshing = false
    @Published var syncError: String?
    @Published var lastSyncAt: Date?

    @AppStorage("manualAddress") var manualAddress: String = ""

    init() {
        snapshot = SyncStore.readAppGroupCache()
        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        syncError = nil

        do {
            let manual = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            let snap: UsageSnapshot
            if manual.isEmpty {
                snap = try await LANClient.discoverAndFetch()
            } else {
                snap = try await LANClient.fetch(manualAddress: manual)
            }
            snapshot = snap
            lastSyncAt = Date()
            SyncStore.writeAppGroupCache(snap)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            syncError = snapshot == nil
                ? "未找到 Mac：请确认 Mac 端「AI 用量」在运行，且两台设备连同一 Wi-Fi"
                : "本次同步失败，正在显示上次缓存的数据"
        }

        if let forecast = try? await CodexResetForecastClient.fetch() {
            snapshot?.codexResetForecast = forecast
            if let snapshot {
                SyncStore.writeAppGroupCache(snapshot)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        isRefreshing = false
    }
}
