import SwiftUI

/// codex-resets.com 重置动态页。
struct ResetsView: View {
    var events: [ResetEvent]

    private var stats: ResetStats { ResetStats.compute(from: events) }

    private var statGrid: [GridItem] {
        [GridItem(.adaptive(minimum: 130), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                resetHero

                LazyVGrid(columns: statGrid, spacing: 12) {
                    StatCard(title: "VERIFIED RESETS", value: "\(stats.count)",
                             caption: "已记录的全局重置")
                    StatCard(title: "AVERAGE GAP",
                             value: stats.averageIntervalDays.map(Fmt.days) ?? "-")
                    StatCard(title: "LONGEST WAIT",
                             value: stats.longestIntervalDays.map(Fmt.days) ?? "-")
                    StatCard(title: "LAST SIGNAL",
                             value: stats.lastReset.map(Fmt.relative) ?? "-",
                             caption: stats.lastReset.map(Fmt.dateTime))
                }

                Card(title: "verified reset timeline") {
                    if events.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在等待重置信号…")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(spacing: 0) {
                                        Circle()
                                            .fill(index == 0 ? Palette.signal : Palette.line)
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 5)
                                        if event.id != events.last?.id {
                                            Rectangle()
                                                .fill(Palette.line)
                                                .frame(width: 1)
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Text(Fmt.relative(event.announcedAt).uppercased())
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(index == 0 ? Palette.signal : Palette.ink)
                                            Text(Fmt.dateTime(event.announcedAt))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(Palette.muted)
                                            Spacer()
                                            if let url = URL(string: event.tweetURL) {
                                                Link("SOURCE ↗", destination: url)
                                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            }
                                        }
                                        Text(event.text)
                                            .font(.callout)
                                            .foregroundStyle(Palette.ink)
                                            .lineLimit(4)
                                            .padding(.bottom, 14)
                                    }
                                }
                            }
                        }
                    }
                }

                Text("SOURCE / codex-resets.com · 非官方社区信号，以客户端显示的限额为准")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(18)
        }
        .background(Palette.canvas)
    }

    private var resetHero: some View {
        Card(title: nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TerminalEyebrow(text: "global reset signal")
                    Spacer()
                    StatusPill(text: events.isEmpty ? "CHECKING FEED" : "FEED ONLINE",
                               isLive: !events.isEmpty)
                }
                Text(stats.lastReset.map(Fmt.relative) ?? "尚无重置信号")
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .tracking(-1.1)
                    .foregroundStyle(Palette.signal)
                    .monospacedDigit()
                Text(stats.lastReset.map { "最近一次已验证的全局重置：\(Fmt.dateTime($0))" }
                     ?? "联网后会自动加载社区记录的全局重置动态。")
                    .font(.callout)
                    .foregroundStyle(Palette.muted)
            }
        }
    }
}
