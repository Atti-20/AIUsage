import SwiftUI
import Charts

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "总览"
    case claude = "Claude"
    case codex = "Codex"
    case resets = "重置动态"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .claude: return "sparkle"
        case .codex: return "terminal"
        case .resets: return "arrow.counterclockwise.circle"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindow: View {
    @EnvironmentObject var store: UsageStore
    @State private var selection: SidebarItem = .overview

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 170)
        } detail: {
            Group {
                if let snapshot = store.snapshot {
                    switch selection {
                    case .overview: OverviewView(snapshot: snapshot)
                    case .claude: SourceDetailView(snapshot: snapshot, source: .claude)
                    case .codex: SourceDetailView(snapshot: snapshot, source: .codex)
                    case .resets: ResetsView(events: snapshot.resets)
                    case .settings: SettingsView()
                    }
                } else if selection == .settings {
                    SettingsView()
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("正在解析本地用量日志…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(selection.rawValue)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
                }
            }
        }
        .task { store.startIfNeeded() }
    }
}

/// Claude / Codex 单来源详情页。
struct SourceDetailView: View {
    var snapshot: UsageSnapshot
    var source: UsageSource

    private var tint: Color { Palette.color(for: source) }

    private var days: [DailyStat] { snapshot.recentDays(30) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                limitsSection

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    let today = snapshot.today.tally(for: source)
                    let total = snapshot.days.reduce(TokenTally()) { $0 + $1.tally(for: source) }
                    StatCard(title: "今日成本", value: Fmt.usd(today.costUSD),
                             caption: "\(Fmt.tokens(today.totalTokens)) tokens")
                    StatCard(title: "近 90 天成本", value: Fmt.usd(total.costUSD),
                             caption: "\(Fmt.tokens(total.totalTokens)) tokens")
                    StatCard(title: "输出 tokens", value: Fmt.tokens(total.output),
                             caption: "非缓存输入 \(Fmt.tokens(total.input))")
                    StatCard(title: "缓存读取", value: Fmt.tokens(total.cacheRead),
                             caption: "缓存写入 \(Fmt.tokens(total.cacheWrite))")
                }

                Card(title: "近 30 天每日成本") {
                    Chart(days) { d in
                        BarMark(x: .value("日期", Fmt.dayKeyToDate(d.day), unit: .day),
                                y: .value("成本", d.tally(for: source).costUSD))
                            .foregroundStyle(tint)
                            .cornerRadius(2)
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) { Text(Fmt.usd(v)) }
                            }
                        }
                    }
                    .frame(height: 160)
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "模型占比") {
                        ModelDonut(models: snapshot.models(for: source))
                    }
                    Card(title: "项目排行") {
                        let projects = Array(snapshot.projects(for: source).prefix(6))
                        let maxCost = projects.first?.tally.costUSD ?? 0
                        if projects.isEmpty {
                            Text("暂无数据").font(.caption).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 4) {
                                ForEach(projects) { p in ProjectRow(project: p, maxCost: maxCost) }
                            }
                        }
                    }
                }

                Card(title: "最近会话") {
                    let sessions = Array(snapshot.sessions(for: source).prefix(12))
                    if sessions.isEmpty {
                        Text("暂无数据").font(.caption).foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sessions) { s in
                                SessionRow(session: s)
                                if s.id != sessions.last?.id { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var limitsSection: some View {
        let windows: [LimitWindow] = source == .claude
            ? (snapshot.claudeLimits?.windows ?? [])
            : (snapshot.codexLimits?.windows ?? [])
        if !windows.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ForEach(windows) { w in
                    LimitCard(source: source, window: w)
                }
            }
        }
        if source == .claude, let limits = snapshot.claudeLimits {
            if let sub = limits.subscription {
                Text("订阅：\(sub)").font(.caption).foregroundStyle(.secondary)
            }
            if let err = limits.error {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        if source == .codex, let limits = snapshot.codexLimits {
            HStack(spacing: 12) {
                if let plan = limits.plan {
                    Text("套餐：\(plan)").font(.caption).foregroundStyle(.secondary)
                }
                if let credits = limits.creditsBalance {
                    Text("积分余额：\(credits)").font(.caption).foregroundStyle(.secondary)
                }
                if let at = limits.capturedAt {
                    Text("快照时间：\(Fmt.relative(at))").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}
