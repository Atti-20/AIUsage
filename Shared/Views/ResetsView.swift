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
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: statGrid, spacing: 12) {
                    StatCard(title: "重置总数", value: "\(stats.count)")
                    StatCard(title: "平均间隔",
                             value: stats.averageIntervalDays.map(Fmt.days) ?? "-")
                    StatCard(title: "最长等待",
                             value: stats.longestIntervalDays.map(Fmt.days) ?? "-")
                    StatCard(title: "上次重置",
                             value: stats.lastReset.map(Fmt.relative) ?? "-",
                             caption: stats.lastReset.map(Fmt.dateTime))
                }

                Card(title: "重置公告（@thsottiaux）") {
                    if events.isEmpty {
                        Text("暂无数据，稍后自动刷新")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(events) { event in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(Fmt.relative(event.announcedAt))
                                            .font(.caption.weight(.semibold))
                                        Text(Fmt.dateTime(event.announcedAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        if let url = URL(string: event.tweetURL) {
                                            Link("查看推文", destination: url)
                                                .font(.caption)
                                        }
                                    }
                                    Text(event.text)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .lineLimit(4)
                                }
                                .padding(.vertical, 8)
                                if event.id != events.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Text("数据来源：codex-resets.com（非官方，监测 OpenAI 产品负责人推文）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
    }
}
