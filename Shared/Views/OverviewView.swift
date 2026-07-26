import SwiftUI

/// 总览页：英雄数字 + 限额环 + 30 天趋势 + 模型/项目排行。
/// Mac 与 iOS 共用，数据来自 UsageSnapshot。
struct OverviewView: View {
    var snapshot: UsageSnapshot

    private var ringGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 230), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                heroCard

                let limits = snapshot.allLimitWindows
                if !limits.isEmpty {
                    LazyVGrid(columns: ringGrid, spacing: 12) {
                        ForEach(limits, id: \.window.id) { item in
                            LimitCard(source: item.source, window: item.window)
                        }
                    }
                }
                if let err = snapshot.claudeLimits?.error {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Card(title: "近 30 天用量趋势") {
                    TrendChart(days: snapshot.recentDays(30))
                }

                HStack(alignment: .top, spacing: 12) {
                    Card(title: "模型成本占比") {
                        ModelDonut(models: snapshot.models)
                    }
                    Card(title: "项目排行") {
                        let projects = Array(snapshot.projects(for: nil).prefix(6))
                        let maxCost = projects.first?.tally.costUSD ?? 0
                        if projects.isEmpty {
                            Text("暂无数据").font(.caption).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(projects) { p in
                                    ProjectRow(project: p, maxCost: maxCost)
                                }
                            }
                        }
                    }
                }

                Text("更新于 \(Fmt.dateTime(snapshot.generatedAt)) · 来自 \(snapshot.deviceName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
            .padding(16)
        }
    }

    /// 英雄卡：今日成本大数字 + 来源拆分 + 本月/累计/重置速览。
    private var heroCard: some View {
        Card(title: nil) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日成本")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(Fmt.usd(snapshot.today.totalCost))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .tracking(-0.8)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    HStack(spacing: 14) {
                        SourceChip(source: .claude, text: Fmt.usd(snapshot.today.claude.costUSD))
                        SourceChip(source: .codex, text: Fmt.usd(snapshot.today.codex.costUSD))
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .leading, spacing: 10) {
                    quickStat("本月", Fmt.usd(snapshot.monthCost))
                    quickStat("近 90 天", Fmt.usd(snapshot.totalCost))
                    if let last = ResetStats.compute(from: snapshot.resets).lastReset {
                        quickStat("Codex 重置", Fmt.relative(last))
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func quickStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }
}
