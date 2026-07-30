import SwiftUI
import Charts

// MARK: - 卡片容器

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 7) {
                    Text(">")
                        .foregroundStyle(Palette.signal)
                    Text(title.uppercased())
                        .foregroundStyle(Palette.muted)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.8)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 1)
        )
    }
}

struct TerminalEyebrow: View {
    var text: String
    var tint: Color = Palette.signal

    var body: some View {
        HStack(spacing: 7) {
            Text(">")
                .foregroundStyle(tint)
            Text(text.uppercased())
                .foregroundStyle(Palette.muted)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .tracking(0.9)
    }
}

struct StatusPill: View {
    var text: String
    var isLive: Bool = true

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isLive ? Palette.signal : Palette.warning)
                .frame(width: 6, height: 6)
                .shadow(color: (isLive ? Palette.signal : Palette.warning).opacity(0.55), radius: 5)
            Text(text)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.surfaceRaised, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
    }
}

struct LimitWarningBanner: View {
    var text: String
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Palette.warning)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .padding(5)
            }
            .buttonStyle(.plain)
            .help("关闭此类提示，可在设置中重新开启")
            .accessibilityLabel("关闭官方限额提示")
        }
        .padding(10)
        .background(Palette.warning.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.warning.opacity(0.34), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CodexResetForecastCard: View {
    var forecast: CodexResetForecast

    var body: some View {
        Card(title: "Codex 全球重置预测") {
            HStack(spacing: 22) {
                probability("24H", forecast.probability24h)
                probability("48H", forecast.probability48h)
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let lastResetAt = forecast.lastResetAt {
                        Text("上次 \(Fmt.relative(lastResetAt))")
                    }
                    if let likelyWindow = forecast.likelyWindow {
                        Text(likelyWindow)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.muted)
            }
            Text("codex-reset.com · 社区预测")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Palette.muted)
        }
    }

    private func probability(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Text("\(value)%")
                .font(.system(size: 23, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.codex)
                .monospacedDigit()
        }
    }
}

// MARK: - 限额环

struct RingGauge: View {
    var percent: Double        // 0–100
    var tint: Color
    var lineWidth: CGFloat = 8
    var size: CGFloat = 64

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(shown, 0), 100) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Fmt.percent(shown))
                .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.utilizationText(percent))
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                shown = percent
            } else {
                // 从当前值出发的临界阻尼弹簧，入场不弹跳
                withAnimation(.spring(response: 0.7, dampingFraction: 1)) {
                    shown = percent
                }
            }
        }
        .onChange(of: percent) { _, newValue in
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 1)) {
                shown = newValue
            }
        }
    }
}

struct LimitCard: View {
    var source: UsageSource
    var window: LimitWindow

    var body: some View {
        Card(title: nil) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Palette.color(for: source))
                            .frame(width: 7, height: 7)
                        Text("\(source.displayName.uppercased()) / \(window.label)")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    Spacer()
                    Text("USED")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.percent(window.utilization))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .tracking(-1)
                        .foregroundStyle(Palette.utilizationText(window.utilization))
                        .monospacedDigit()
                    Spacer()
                    if let resetsAt = window.resetsAt {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("RESET IN")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(Palette.muted)
                            Text(Fmt.countdown(to: resetsAt))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Palette.ink)
                                .monospacedDigit()
                        }
                    } else {
                        Text("RESET —")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.line)
                        Capsule()
                            .fill(Palette.utilizationText(window.utilization))
                            .frame(width: max(4, geo.size.width * min(max(window.utilization, 0), 100) / 100))
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

// MARK: - 数值卡片

struct StatCard: View {
    var title: String
    var value: String
    var caption: String?
    var valueColor: Color = Palette.ink

    var body: some View {
        Card(title: title) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .tracking(-0.3)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// 带彩色圆点的小数值行（用于英雄卡的来源拆分）。
struct SourceChip: View {
    var source: UsageSource
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Palette.color(for: source)).frame(width: 7, height: 7)
            Text(source.displayName)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
        }
    }
}

// MARK: - 趋势图（每日成本，Claude / Codex 堆叠柱）

struct TrendChart: View {
    var days: [DailyStat]
    var showClaude: Bool = true
    var showCodex: Bool = true
    @State private var selection: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headerText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            if showClaude || showCodex {
                Chart {
                    ForEach(days) { d in
                        if showClaude {
                            BarMark(
                                x: .value("日期", Fmt.dayKeyToDate(d.day), unit: .day),
                                y: .value("成本", d.claude.costUSD)
                            )
                            .foregroundStyle(by: .value("来源", "Claude"))
                            .cornerRadius(2.5)
                        }
                        if showCodex {
                            BarMark(
                                x: .value("日期", Fmt.dayKeyToDate(d.day), unit: .day),
                                y: .value("成本", d.codex.costUSD)
                            )
                            .foregroundStyle(by: .value("来源", "Codex"))
                            .cornerRadius(2.5)
                        }
                    }
                    if let selection,
                       let d = day(at: selection) {
                        RuleMark(x: .value("选中", Fmt.dayKeyToDate(d.day), unit: .day))
                            .foregroundStyle(.quaternary)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartForegroundStyleScale(domain: ["Claude", "Codex"],
                                           range: [Palette.claude, Palette.codex])
                .chartXSelection(value: $selection)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(days.count / 4, 2))) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.quaternary)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Fmt.usd(v)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                Text("> 用量来源均已隐藏，可在设置中重新开启")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            }
        }
    }

    private func day(at date: Date) -> DailyStat? {
        days.first { Calendar.current.isDate(Fmt.dayKeyToDate($0.day), inSameDayAs: date) }
    }

    private var headerText: String {
        guard let selection, let d = day(at: selection) else {
            let total = days.reduce(0) {
                $0 + $1.visibleCost(showClaude: showClaude, showCodex: showCodex)
            }
            return "近 \(days.count) 天合计 \(Fmt.usd(total))"
        }
        var parts: [String] = []
        if showClaude { parts.append("Claude \(Fmt.usd(d.claude.costUSD))") }
        if showCodex { parts.append("Codex \(Fmt.usd(d.codex.costUSD))") }
        return "\(Fmt.shortDay(d.day))  \(parts.joined(separator: " · "))"
    }
}

// MARK: - 模型占比（环图 + 图例）

struct ModelDonut: View {
    var models: [ModelStat]
    var topN: Int = 5

    private struct Slice: Identifiable {
        var name: String
        var cost: Double
        var color: Color
        var id: String { name }
    }

    private var slices: [Slice] {
        let sorted = models.sorted { $0.tally.costUSD > $1.tally.costUSD }
        var out: [Slice] = []
        for (i, m) in sorted.prefix(topN).enumerated() {
            out.append(Slice(name: shortModelName(m.model),
                             cost: m.tally.costUSD,
                             color: Palette.categorical[min(i, Palette.categorical.count - 1)]))
        }
        let rest = sorted.dropFirst(topN).reduce(0.0) { $0 + $1.tally.costUSD }
        if rest > 0 {
            out.append(Slice(name: "其他", cost: rest, color: Palette.categorical.last!))
        }
        return out
    }

    var body: some View {
        let data = slices
        let total = data.reduce(0) { $0 + $1.cost }
        HStack(spacing: 18) {
            Chart(data) { s in
                SectorMark(angle: .value("成本", s.cost),
                           innerRadius: .ratio(0.64),
                           angularInset: 1.6)
                    .foregroundStyle(s.color)
                    .cornerRadius(2)
            }
            .frame(width: 116, height: 116)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(data) { s in
                    HStack(spacing: 6) {
                        Circle().fill(s.color).frame(width: 8, height: 8)
                        Text(s.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(total > 0 ? Fmt.percent(s.cost / total * 100) : "-")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

func shortModelName(_ model: String) -> String {
    model
        .replacingOccurrences(of: "claude-", with: "")
        .replacingOccurrences(of: "-20[0-9]{6}$", with: "", options: .regularExpression)
}

// MARK: - 项目 / 会话列表行

struct ProjectRow: View {
    var project: ProjectStat
    var maxCost: Double
    var rank: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                if let rank {
                    Text(String(format: "#%02d", rank))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Palette.muted)
                        .frame(width: 28, alignment: .leading)
                }
                Circle().fill(Palette.color(for: project.source)).frame(width: 7, height: 7)
                Text(project.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(project.source.displayName)
                    .font(.caption2)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(Fmt.usd(project.tally.costUSD))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.5))
                    Capsule()
                        .fill(Palette.color(for: project.source))
                        .frame(width: maxCost > 0 ? max(geo.size.width * project.tally.costUSD / maxCost, 4) : 4)
                }
            }
            .frame(height: 5)
            Text("\(project.sessionCount) 个会话 · \(Fmt.tokens(project.tally.totalTokens)) tokens")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SessionRow: View {
    var session: SessionStat

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Palette.color(for: session.source)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title ?? String(session.sessionID.prefix(8)))
                    .font(.callout)
                    .lineLimit(1)
                Text("\(session.project) · \(session.lastActivity.map(Fmt.relative) ?? "-")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.usd(session.tally.costUSD))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("\(Fmt.tokens(session.tally.totalTokens))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
