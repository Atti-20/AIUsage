import SwiftUI

/// macOS 主窗口只承载核心用量；低频配置使用系统 Settings 场景。
struct MainWindow: View {
    @EnvironmentObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    @AppStorage(DisplayPreferenceKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(DisplayPreferenceKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(DisplayPreferenceKeys.showOfficialLimitWarnings) private var showOfficialLimitWarnings = true
    @AppStorage(DisplayPreferenceKeys.showCodexResetPrediction) private var showCodexResetPrediction = true

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                OverviewView(
                    snapshot: snapshot,
                    showClaudeUsage: showClaudeUsage,
                    showCodexUsage: showCodexUsage,
                    showOfficialLimitWarnings: showOfficialLimitWarnings,
                    showCodexResetPrediction: showCodexResetPrediction,
                    dismissOfficialLimitWarnings: {
                        showOfficialLimitWarnings = false
                    }
                )
            } else {
                ProgressView()
                    .tint(Palette.signal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.canvas)
            }
        }
        .navigationTitle("AI 用量")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.refresh()
                } label: {
                    if store.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
                .help("刷新")

                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("设置")
            }
        }
        .task { store.startIfNeeded() }
        .tint(Palette.signal)
    }
}
