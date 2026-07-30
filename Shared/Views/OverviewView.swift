import SwiftUI

/// 总览页：限额窗口优先，随后呈现成本与趋势。
/// Mac 与 iOS 共用，数据来自 UsageSnapshot。
struct OverviewView: View {
    var snapshot: UsageSnapshot
    var showClaudeUsage: Bool = true
    var showCodexUsage: Bool = true
    var showOfficialLimitWarnings: Bool = true
    var showCodexResetPrediction: Bool = true
    var dismissOfficialLimitWarnings: () -> Void = {}

    private var ringGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 250), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let limits = snapshot.allLimitWindows.filter {
                    snapshot.isSourceVisible(
                        $0.source,
                        showClaude: showClaudeUsage,
                        showCodex: showCodexUsage
                    )
                }
                if !limits.isEmpty {
                    LazyVGrid(columns: ringGrid, spacing: 12) {
                        ForEach(limits, id: \.window.id) { item in
                            LimitCard(source: item.source, window: item.window)
                        }
                    }
                }
                if showClaudeUsage,
                   showOfficialLimitWarnings,
                   let err = snapshot.claudeLimits?.error {
                    LimitWarningBanner(
                        text: err,
                        onDismiss: dismissOfficialLimitWarnings
                    )
                }
                if showCodexUsage,
                   showCodexResetPrediction,
                   let forecast = snapshot.codexResetForecast {
                    CodexResetForecastCard(forecast: forecast)
                }

                if !showClaudeUsage && !showCodexUsage {
                    Card(title: nil) {
                        Label("用量显示已关闭", systemImage: "eye.slash")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                }

                if showClaudeUsage || showCodexUsage {
                    costHero

                    if !visibleProjects.isEmpty {
                        Card(title: "项目用量排名") {
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(visibleProjects.prefix(5).enumerated()),
                                    id: \.element.id
                                ) { index, project in
                                    ProjectRow(
                                        project: project,
                                        maxCost: visibleProjects.first?.tally.costUSD ?? 0,
                                        rank: index + 1
                                    )
                                    if index < min(visibleProjects.count, 5) - 1 {
                                        Divider().overlay(Palette.line)
                                    }
                                }
                            }
                        }
                    }

                    Card(title: "近 30 天") {
                        TrendChart(
                            days: snapshot.recentDays(30),
                            showClaude: showClaudeUsage,
                            showCodex: showCodexUsage
                        )
                    }
                }

                Text("更新于 \(Fmt.dateTime(snapshot.generatedAt))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }
            .padding(18)
        }
        .background(Palette.canvas)
    }

    /// 成本作为次级英雄区，避免盖过用户最关心的限额与重置时间。
    private var costHero: some View {
        Card(title: nil) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    costPrimary
                    Spacer(minLength: 18)
                    HStack(spacing: 24) {
                        quickStat("MONTH", Fmt.usd(visibleMonthCost))
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    costPrimary
                    Divider().overlay(Palette.line)
                    HStack(spacing: 24) {
                        quickStat("MONTH", Fmt.usd(visibleMonthCost))
                    }
                }
            }
        }
    }

    private var costPrimary: some View {
        VStack(alignment: .leading, spacing: 8) {
            TerminalEyebrow(text: "今日预估成本")
            Text(Fmt.usd(visibleTodayCost))
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .tracking(-1.4)
                .foregroundStyle(Palette.signal)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 14) {
                if showClaudeUsage {
                    SourceChip(source: .claude, text: Fmt.usd(snapshot.today.claude.costUSD))
                }
                if showCodexUsage {
                    SourceChip(source: .codex, text: Fmt.usd(snapshot.today.codex.costUSD))
                }
            }
        }
    }

    private func quickStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
    }

    private var visibleTodayCost: Double {
        snapshot.today.visibleCost(
            showClaude: showClaudeUsage,
            showCodex: showCodexUsage
        )
    }

    private var visibleMonthCost: Double {
        snapshot.visibleMonthCost(
            showClaude: showClaudeUsage,
            showCodex: showCodexUsage
        )
    }

    private var visibleProjects: [ProjectStat] {
        snapshot.visibleProjects(
            showClaude: showClaudeUsage,
            showCodex: showCodexUsage
        )
    }

}
