import SwiftUI

/// 总览页：限额窗口优先，随后呈现成本与趋势。
/// Mac 与 iOS 共用，数据来自 UsageSnapshot。
struct OverviewView: View {
    var snapshot: UsageSnapshot

    private var ringGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 250), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader

                let limits = snapshot.allLimitWindows
                if !limits.isEmpty {
                    TerminalEyebrow(text: "active limit windows")
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

                costHero

                Card(title: "30 day usage signal") {
                    TrendChart(days: snapshot.recentDays(30))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], alignment: .leading, spacing: 12) {
                    Card(title: "model cost share") {
                        ModelDonut(models: snapshot.models)
                    }
                    Card(title: "top projects") {
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

                HStack(spacing: 8) {
                    Circle().fill(Palette.signal).frame(width: 5, height: 5)
                    Text("SYNC \(Fmt.dateTime(snapshot.generatedAt))  /  \(snapshot.deviceName)")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
            }
            .padding(18)
        }
        .background(Palette.canvas)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TerminalEyebrow(text: "usage monitor / local")
                Spacer()
                StatusPill(text: "LIVE SNAPSHOT")
            }
            Text("额度还够用吗？")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .tracking(-1.2)
                .foregroundStyle(Palette.ink)
            Text("Claude Code 与 Codex 的限额、重置时间和本地成本汇总。原始会话始终留在你的设备上。")
                .font(.callout)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    /// 成本作为次级英雄区，避免盖过用户最关心的限额与重置时间。
    private var costHero: some View {
        Card(title: nil) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 24) {
                    costPrimary
                    Spacer(minLength: 18)
                    HStack(spacing: 24) {
                        quickStat("MONTH", Fmt.usd(snapshot.monthCost))
                        quickStat("90 DAYS", Fmt.usd(snapshot.totalCost))
                        if let last = ResetStats.compute(from: snapshot.resets).lastReset {
                            quickStat("GLOBAL RESET", Fmt.relative(last))
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    costPrimary
                    Divider().overlay(Palette.line)
                    HStack(spacing: 24) {
                        quickStat("MONTH", Fmt.usd(snapshot.monthCost))
                        quickStat("90 DAYS", Fmt.usd(snapshot.totalCost))
                        if let last = ResetStats.compute(from: snapshot.resets).lastReset {
                            quickStat("RESET", Fmt.relative(last))
                        }
                    }
                }
            }
        }
    }

    private var costPrimary: some View {
        VStack(alignment: .leading, spacing: 8) {
            TerminalEyebrow(text: "today / estimated cost")
            Text(Fmt.usd(snapshot.today.totalCost))
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .tracking(-1.4)
                .foregroundStyle(Palette.signal)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 14) {
                SourceChip(source: .claude, text: Fmt.usd(snapshot.today.claude.costUSD))
                SourceChip(source: .codex, text: Fmt.usd(snapshot.today.codex.costUSD))
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
}
