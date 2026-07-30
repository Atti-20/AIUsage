import SwiftUI

/// 菜单栏下拉面板：关键限额 + 今日成本一眼可见。
struct MenuBarView: View {
    @EnvironmentObject var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage(DisplayPreferenceKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(DisplayPreferenceKeys.showCodexUsage) private var showCodexUsage = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 5) {
                    Text("~/")
                        .foregroundStyle(Palette.signal)
                    Text("AIUsage")
                        .foregroundStyle(Palette.ink)
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            }

            if let snapshot = store.snapshot {
                let visibleLimits = snapshot.allLimitWindows.filter {
                    snapshot.isSourceVisible(
                        $0.source,
                        showClaude: showClaudeUsage,
                        showCodex: showCodexUsage
                    )
                }
                if showClaudeUsage || showCodexUsage {
                    HStack(spacing: 16) {
                        ForEach(Array(visibleLimits.prefix(3)), id: \.window.id) { item in
                            VStack(spacing: 4) {
                                RingGauge(percent: item.window.utilization,
                                          tint: Palette.color(for: item.source),
                                          lineWidth: 6, size: 48)
                                Text("\(item.source.displayName) \(item.window.label)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Palette.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    Grid(alignment: .leading, verticalSpacing: 4) {
                        GridRow {
                            Text("TODAY COST").foregroundStyle(Palette.muted)
                            Text(Fmt.usd(snapshot.today.visibleCost(
                                showClaude: showClaudeUsage,
                                showCodex: showCodexUsage
                            )))
                            .gridColumnAlignment(.trailing)
                        }
                        GridRow {
                            Text("MONTH").foregroundStyle(Palette.muted)
                            Text(Fmt.usd(snapshot.visibleMonthCost(
                                showClaude: showClaudeUsage,
                                showCodex: showCodexUsage
                            )))
                        }
                    }
                    .font(.system(size: 11, design: .monospaced).monospacedDigit())
                } else {
                    Label("用量显示已关闭", systemImage: "eye.slash")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
                }
            } else {
                HStack {
                    ProgressView().controlSize(.small)
                    Text(store.isRefreshing ? "正在读取…" : "暂无数据")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }

            Divider()

            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("打开统计窗口", systemImage: "chart.bar.xaxis")
                }
                Spacer()
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
                .help("立即刷新")
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("退出")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320)
        .background(Palette.canvas)
        .tint(Palette.signal)
    }
}
