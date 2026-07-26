import WidgetKit
import SwiftUI

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsageWidget()
    }
}

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: SyncStore.readAppGroupCache())
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: Date(), snapshot: SyncStore.readAppGroupCache())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct UsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsageWidget", provider: UsageProvider()) { entry in
            UsageWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AI 用量")
        .description("Claude 与 Codex 的限额进度和今日成本")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct UsageWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UsageEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: mediumView(snapshot)
            default: smallView(snapshot)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "icloud.and.arrow.down")
                    .foregroundStyle(.secondary)
                Text("打开 App 同步数据")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func smallView(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let item = snapshot.allLimitWindows.first {
                HStack(spacing: 8) {
                    RingGauge(percent: item.window.utilization,
                              tint: Palette.color(for: item.source),
                              lineWidth: 5, size: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.source.displayName)
                            .font(.caption2.weight(.semibold))
                        Text(item.window.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("今日 " + Fmt.usd(snapshot.today.totalCost))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
            Text("本月 " + Fmt.usd(snapshot.monthCost))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumView(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(snapshot.allLimitWindows.prefix(3)), id: \.window.id) { item in
                VStack(spacing: 3) {
                    RingGauge(percent: item.window.utilization,
                              tint: Palette.color(for: item.source),
                              lineWidth: 5, size: 44)
                    Text(item.source.displayName)
                        .font(.caption2.weight(.semibold))
                    Text(item.window.label)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("今日")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Fmt.usd(snapshot.today.totalCost))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text("本月 " + Fmt.usd(snapshot.monthCost))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
