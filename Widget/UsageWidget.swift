import SwiftUI
import WidgetKit

@main
struct AIUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        AppUsageWidget()
        GlassUsageWidget()
    }
}

private enum UsageWidgetStyle {
    case app
    case glass
}

private struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

private struct UsageProvider: TimelineProvider {
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

private struct AppUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsageWidget.App", provider: UsageProvider()) { entry in
            UsageWidgetRoot(entry: entry, style: .app)
        }
        .configurationDisplayName("AI 用量")
        .description("与 App 一致的深色用量卡片")
        .containerBackgroundRemovable(false)
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct GlassUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsageWidget.Glass", provider: UsageProvider()) { entry in
            UsageWidgetRoot(entry: entry, style: .glass)
        }
        .configurationDisplayName("AI 用量 · 液态玻璃")
        .description("适配 iOS 26 液态玻璃与系统着色")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct UsageWidgetRoot: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry
    let style: UsageWidgetStyle

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inlineView
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .systemMedium:
                homeSurface { homeMediumView }
            default:
                homeSurface { homeSmallView }
            }
        }
        .containerBackground(for: .widget) {
            if style == .app {
                Palette.canvas
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func homeSurface<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if style == .glass {
            if #available(iOSApplicationExtension 26.0, *) {
                content()
                    .padding(2)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))
            } else {
                content()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            }
        } else {
            content()
        }
    }

    private var homeSmallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let limit = primaryLimit {
                HStack(spacing: 9) {
                    RingGauge(
                        percent: limit.window.utilization,
                        tint: homeTint(for: limit.source),
                        lineWidth: 5,
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(limit.source.displayName)
                            .font(.caption.weight(.semibold))
                        Text(limit.window.label)
                            .font(.caption2)
                            .foregroundStyle(homeSecondary)
                        if let reset = limit.window.resetsAt {
                            Text(Fmt.countdown(to: reset))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(homeSecondary)
                        }
                    }
                }
            } else {
                Image(systemName: entry.snapshot == nil ? "icloud.and.arrow.down" : "eye.slash")
                    .foregroundStyle(homeSecondary)
            }
            Spacer(minLength: 0)
            homeCost
        }
        .foregroundStyle(homePrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var homeMediumView: some View {
        HStack(spacing: 16) {
            ForEach(Array(visibleLimits.prefix(2)), id: \.window.id) { limit in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(homeTint(for: limit.source))
                            .frame(width: 7, height: 7)
                        Text(limit.source.displayName)
                            .font(.caption.weight(.semibold))
                    }
                    Text(Fmt.percent(limit.window.utilization))
                        .font(.title2.bold().monospacedDigit())
                    Text(limit.window.resetsAt.map(Fmt.countdown) ?? limit.window.label)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(homeSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if visibleLimits.isEmpty {
                Label(entry.snapshot == nil ? "打开 App 同步" : "用量显示已关闭",
                      systemImage: entry.snapshot == nil ? "icloud.and.arrow.down" : "eye.slash")
                    .font(.caption)
                    .foregroundStyle(homeSecondary)
                    .frame(maxWidth: .infinity)
            }
            Divider().overlay(homeSecondary.opacity(0.35))
            homeCost
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(homePrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeCost: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("今日")
                .font(.caption2)
                .foregroundStyle(homeSecondary)
            Text(Fmt.usd(todayCost))
                .font(.headline.monospacedDigit())
            Text("本月 \(Fmt.usd(monthCost))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(homeSecondary)
        }
    }

    private var inlineView: some View {
        let percent = primaryLimit.map { Fmt.percent($0.window.utilization) } ?? "—"
        let reset = primaryLimit?.window.resetsAt.map(Fmt.countdown) ?? "等待同步"
        return Label("\(percent) · \(reset)", systemImage: "gauge.with.dots.needle.67percent")
    }

    private var circularView: some View {
        Gauge(value: primaryLimit?.window.utilization ?? 0, in: 0...100) {
            Image(systemName: "terminal")
        } currentValueLabel: {
            Text(primaryLimit.map { "\(Int($0.window.utilization.rounded()))" } ?? "—")
                .font(.caption2.monospacedDigit())
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(primaryLimit?.source.displayName ?? "AI 用量")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(primaryLimit.map { Fmt.percent($0.window.utilization) } ?? "—")
                    .font(.caption.monospacedDigit())
            }
            Gauge(value: primaryLimit?.window.utilization ?? 0, in: 0...100) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            Text(primaryLimit?.window.resetsAt.map(Fmt.countdown) ?? "打开 App 同步")
                .font(.caption2.monospacedDigit())
        }
        .widgetAccentable()
    }

    private var preferences: UserDefaults? {
        UserDefaults(suiteName: SyncStore.appGroupID)
    }

    private var showClaudeUsage: Bool {
        preference(DisplayPreferenceKeys.showClaudeUsage)
    }

    private var showCodexUsage: Bool {
        preference(DisplayPreferenceKeys.showCodexUsage)
    }

    private var visibleLimits: [(source: UsageSource, window: LimitWindow)] {
        guard let snapshot = entry.snapshot else { return [] }
        return snapshot.allLimitWindows.filter {
            snapshot.isSourceVisible(
                $0.source,
                showClaude: showClaudeUsage,
                showCodex: showCodexUsage
            )
        }
    }

    private var primaryLimit: (source: UsageSource, window: LimitWindow)? {
        visibleLimits.first
    }

    private var todayCost: Double {
        entry.snapshot?.today.visibleCost(
            showClaude: showClaudeUsage,
            showCodex: showCodexUsage
        ) ?? 0
    }

    private var monthCost: Double {
        entry.snapshot?.visibleMonthCost(
            showClaude: showClaudeUsage,
            showCodex: showCodexUsage
        ) ?? 0
    }

    private var homePrimary: Color {
        style == .app ? Palette.ink : .primary
    }

    private var homeSecondary: Color {
        style == .app ? Palette.muted : .secondary
    }

    private func homeTint(for source: UsageSource) -> Color {
        style == .app ? Palette.color(for: source) : .accentColor
    }

    private func preference(_ key: String) -> Bool {
        guard let preferences else { return true }
        return preferences.object(forKey: key) == nil
            ? true
            : preferences.bool(forKey: key)
    }
}
