import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../fmt.dart';
import '../models.dart';

/// 与 SwiftUI 端一致的终端仪表盘设计系统。
class Palette {
  static const canvas = Color(0xFF0B0F0D);
  static const surface = Color(0xFF101713);
  static const surfaceRaised = Color(0xFF141E18);
  static const line = Color(0xFF26362C);
  static const ink = Color(0xFFE8EEE9);
  static const muted = Color(0xFF87938B);
  static const signal = Color(0xFF69F08A);
  static const warning = Color(0xFFE5A965);
  static const danger = Color(0xFFFF7777);
  static const claudeColor = Color(0xFFE08A52);

  static Color claude(BuildContext _) => claudeColor;
  static Color codex(BuildContext _) => signal;
  static Color source(BuildContext c, String s) =>
      s == 'claude' ? claude(c) : codex(c);

  static List<Color> categorical(BuildContext c) {
    return [
      claude(c),
      codex(c),
      const Color(0xFFA895FF),
      const Color(0xFF4BC6AE),
      const Color(0xFFE0BE54),
      muted,
    ];
  }

  static Color utilizationText(BuildContext c, double percent) {
    if (percent >= 90) return danger;
    if (percent >= 70) return warning;
    return signal;
  }
}

String sourceName(String s) => s == 'claude' ? 'Claude' : 'Codex';

class AppCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const AppCard({super.key, this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            TerminalEyebrow(text: title!),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class TerminalEyebrow extends StatelessWidget {
  final String text;
  final Color tint;
  const TerminalEyebrow({
    super.key,
    required this.text,
    this.tint = Palette.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '>',
          style: TextStyle(
            color: tint,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: Palette.muted,
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool isLive;
  const StatusPill({super.key, required this.text, this.isLive = true});

  @override
  Widget build(BuildContext context) {
    final tint = isLive ? Palette.signal : Palette.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.surfaceRaised,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: tint.withValues(alpha: 0.45), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Palette.muted,
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class RingGauge extends StatelessWidget {
  final double percent; // 0-100
  final Color tint;
  final double size;
  final double lineWidth;
  const RingGauge({
    super.key,
    required this.percent,
    required this.tint,
    this.size = 64,
    this.lineWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.clamp(0, 100)),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value / 100, tint, lineWidth),
          child: Center(
            child: Text(
              Fmt.percent(value),
              style: TextStyle(
                fontSize: size * 0.24,
                fontWeight: FontWeight.w600,
                color: Palette.utilizationText(context, percent),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color tint;
  final double lineWidth;
  _RingPainter(this.fraction, this.tint, this.lineWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - lineWidth) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..color = tint.withValues(alpha: 0.15);
    canvas.drawCircle(center, radius, track);
    if (fraction > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..color = tint;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0),
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.tint != tint ||
      old.lineWidth != lineWidth;
}

class LimitCard extends StatelessWidget {
  final String source;
  final LimitWindow window;
  const LimitCard({super.key, required this.source, required this.window});

  @override
  Widget build(BuildContext context) {
    final tint = Palette.source(context, source);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${sourceName(source).toUpperCase()} / ${window.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.muted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'USED',
                style: TextStyle(
                  color: Palette.muted,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.percent(window.utilization),
                style: TextStyle(
                  color: Palette.utilizationText(context, window.utilization),
                  fontFamily: 'monospace',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              if (window.resetsAt != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'RESET IN',
                      style: TextStyle(
                        color: Palette.muted,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.countdown(window.resetsAt!),
                      style: const TextStyle(
                        color: Palette.ink,
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'RESET —',
                  style: TextStyle(
                    color: Palette.muted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (window.utilization / 100).clamp(0, 1),
              minHeight: 5,
              color: Palette.utilizationText(context, window.utilization),
              backgroundColor: Palette.line,
            ),
          ),
        ],
      ),
    );
  }
}

class SourceChip extends StatelessWidget {
  final String source;
  final String text;
  const SourceChip({super.key, required this.source, required this.text});

  @override
  Widget build(BuildContext context) {
    final tint = Palette.source(context, source);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          sourceName(source),
          style: const TextStyle(
            color: Palette.muted,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 30 天堆叠柱状趋势图（自绘）。
class TrendChart extends StatelessWidget {
  final List<DailyStat> days;
  final bool showClaude;
  final bool showCodex;
  const TrendChart({
    super.key,
    required this.days,
    this.showClaude = true,
    this.showCodex = true,
  });

  @override
  Widget build(BuildContext context) {
    final total = days.fold(
      0.0,
      (sum, day) =>
          sum + day.visibleCost(showClaude: showClaude, showCodex: showCodex),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '近 ${days.length} 天合计 ${Fmt.usd(total)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendPainter(
              days,
              showClaude,
              showCodex,
              Palette.claude(context),
              Palette.codex(context),
              Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.35),
              Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (showClaude)
              _legendDot(context, Palette.claude(context), 'Claude'),
            if (showClaude && showCodex) const SizedBox(width: 14),
            if (showCodex) _legendDot(context, Palette.codex(context), 'Codex'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<DailyStat> days;
  final bool showClaude;
  final bool showCodex;
  final Color claude;
  final Color codex;
  final Color grid;
  final Color label;
  _TrendPainter(
    this.days,
    this.showClaude,
    this.showCodex,
    this.claude,
    this.codex,
    this.grid,
    this.label,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    const leftPad = 0.0, rightPad = 44.0, bottomPad = 18.0;
    final plotW = size.width - leftPad - rightPad;
    final plotH = size.height - bottomPad;
    final maxCost = days.fold(
      0.0,
      (maxValue, day) => math.max(
        maxValue,
        day.visibleCost(showClaude: showClaude, showCodex: showCodex),
      ),
    );
    final top = maxCost <= 0 ? 1.0 : maxCost * 1.08;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plotH - plotH * i / 3;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + plotW, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: Fmt.usd(top * i / 3),
          style: TextStyle(fontSize: 10, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad + plotW + 6, y - tp.height / 2));
    }

    final n = days.length;
    final slot = plotW / n;
    final barW = math.max(math.min(slot * 0.62, 22.0), 2.0);
    final claudePaint = Paint()..color = claude;
    final codexPaint = Paint()..color = codex;

    for (var i = 0; i < n; i++) {
      final d = days[i];
      final x = leftPad + slot * i + (slot - barW) / 2;
      final hClaude = showClaude ? plotH * (d.claude.costUSD / top) : 0.0;
      final hCodex = showCodex ? plotH * (d.codex.costUSD / top) : 0.0;
      // Claude 在下、Codex 在上，段间留 2px 表面间隙
      if (hClaude > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, plotH - hClaude, barW, hClaude),
            const Radius.circular(2),
          ),
          claudePaint,
        );
      }
      if (hCodex > 0.5) {
        final gap = hClaude > 0.5 ? 2.0 : 0.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, plotH - hClaude - gap - hCodex, barW, hCodex),
            const Radius.circular(2),
          ),
          codexPaint,
        );
      }
    }

    // X 轴标签：约 5 个
    final step = math.max(n ~/ 5, 1);
    for (var i = 0; i < n; i += step) {
      final tp = TextPainter(
        text: TextSpan(
          text: Fmt.shortDay(days[i].day),
          style: TextStyle(fontSize: 10, color: label),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = leftPad + slot * i + slot / 2 - tp.width / 2;
      tp.paint(canvas, Offset(x, plotH + 4));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.days != days ||
      old.showClaude != showClaude ||
      old.showCodex != showCodex ||
      old.claude != claude ||
      old.codex != codex ||
      old.grid != grid ||
      old.label != label;
}

/// 模型占比环图（自绘）+ 图例。
class ModelDonut extends StatelessWidget {
  final List<ModelStat> models;
  const ModelDonut({super.key, required this.models});

  @override
  Widget build(BuildContext context) {
    final sorted = [...models]
      ..sort((a, b) => b.tally.costUSD.compareTo(a.tally.costUSD));
    final colors = Palette.categorical(context);
    final slices = <(String, double, Color)>[];
    for (var i = 0; i < sorted.length && i < 5; i++) {
      slices.add((
        shortModelName(sorted[i].model),
        sorted[i].tally.costUSD,
        colors[math.min(i, colors.length - 1)],
      ));
    }
    final rest = sorted.skip(5).fold(0.0, (s, m) => s + m.tally.costUSD);
    if (rest > 0) slices.add(('其他', rest, colors.last));
    final total = slices.fold(0.0, (s, e) => s + e.$2);

    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(painter: _DonutPainter(slices)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        total > 0 ? Fmt.percent(s.$2 / total * 100) : '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String shortModelName(String model) =>
    model.replaceAll('claude-', '').replaceAll(RegExp(r'-20[0-9]{6}$'), '');

class _DonutPainter extends CustomPainter {
  final List<(String, double, Color)> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (s, e) => s + e.$2);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final thickness = outer * 0.36;
    final radius = outer - thickness / 2;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = 2 * math.pi * (s.$2 / total);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = s.$3;
      const inset = 0.02;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + inset,
        math.max(sweep - inset * 2, 0.01),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

class ProjectRow extends StatelessWidget {
  final ProjectStat project;
  final double maxCost;
  const ProjectRow({super.key, required this.project, required this.maxCost});

  @override
  Widget build(BuildContext context) {
    final tint = Palette.source(context, project.source);
    final fraction = maxCost > 0
        ? (project.tally.costUSD / maxCost).clamp(0.02, 1.0)
        : 0.02;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                Fmt.usd(project.tally.costUSD),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 5,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 5,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 3),
          Text(
            '${project.sessionCount} 个会话 · ${Fmt.tokens(project.tally.totalTokens)} tokens',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
