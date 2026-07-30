import 'package:flutter/material.dart';

import '../fmt.dart';
import '../models.dart';
import '../store.dart';
import 'widgets.dart';

/// 总览页（桌面与移动共用）。
class DashboardPage extends StatelessWidget {
  final AppStore store;
  const DashboardPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final snapshot = store.snapshot;
    if (snapshot == null) {
      return _EmptyView(store: store);
    }
    final limits = snapshot.allLimitWindows
        .where(
          (item) => snapshot.isSourceVisible(
            item.$1,
            showClaude: store.showClaudeUsage,
            showCodex: store.showCodexUsage,
          ),
        )
        .toList();
    final projects = snapshot
        .visibleProjects(
          showClaude: store.showClaudeUsage,
          showCodex: store.showCodexUsage,
        )
        .take(5)
        .toList();
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        key: const PageStorageKey('dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          if (store.syncError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.warning.withValues(alpha: 0.08),
                border: Border.all(
                  color: Palette.warning.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                store.syncError!,
                style: const TextStyle(
                  color: Palette.warning,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          if (limits.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 640;
                final width = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (source, window) in limits)
                      SizedBox(
                        width: width,
                        child: LimitCard(source: source, window: window),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
          ],
          if (store.showClaudeUsage &&
              store.showOfficialLimitWarnings &&
              snapshot.claudeLimits?.error != null)
            _limitWarning(
              snapshot.claudeLimits!.error!,
              store.setShowOfficialLimitWarnings,
            ),
          if (store.showCodexUsage &&
              store.showCodexResetPrediction &&
              snapshot.codexResetForecast != null) ...[
            _resetForecast(snapshot.codexResetForecast!),
            const SizedBox(height: 12),
          ],
          if (!store.showClaudeUsage && !store.showCodexUsage) ...[
            AppCard(
              child: const Row(
                children: [
                  Icon(Icons.visibility_off_outlined, color: Palette.muted),
                  SizedBox(width: 8),
                  Text(
                    '用量显示已关闭',
                    style: TextStyle(
                      color: Palette.muted,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (store.showClaudeUsage || store.showCodexUsage) ...[
            _costHero(context, snapshot),
            const SizedBox(height: 12),
            if (projects.isNotEmpty) ...[
              AppCard(
                title: '项目用量排名',
                child: Column(
                  children: [
                    for (final (index, project) in projects.indexed) ...[
                      ProjectRow(
                        project: project,
                        maxCost: projects.first.tally.costUSD,
                        rank: index + 1,
                      ),
                      if (index < projects.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppCard(
              title: '近 30 天',
              child: TrendChart(
                days: snapshot.recentDays(30),
                showClaude: store.showClaudeUsage,
                showCodex: store.showCodexUsage,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text(
              '更新于 ${Fmt.dateTime(snapshot.generatedAt)}',
              style: const TextStyle(
                color: Palette.muted,
                fontFamily: 'monospace',
                fontSize: 9,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costHero(BuildContext context, UsageSnapshot snapshot) {
    final today = snapshot.today;
    final visibleTodayCost = today.visibleCost(
      showClaude: store.showClaudeUsage,
      showCodex: store.showCodexUsage,
    );
    final visibleMonthCost = snapshot.visibleMonthCost(
      showClaude: store.showClaudeUsage,
      showCodex: store.showCodexUsage,
    );
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 580;
          final primary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TerminalEyebrow(text: '今日预估成本'),
              const SizedBox(height: 8),
              Text(
                Fmt.usd(visibleTodayCost),
                style: const TextStyle(
                  color: Palette.signal,
                  fontFamily: 'monospace',
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 5,
                children: [
                  if (store.showClaudeUsage)
                    SourceChip(
                      source: 'claude',
                      text: Fmt.usd(today.claude.costUSD),
                    ),
                  if (store.showCodexUsage)
                    SourceChip(
                      source: 'codex',
                      text: Fmt.usd(today.codex.costUSD),
                    ),
                ],
              ),
            ],
          );
          final statsRow = Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [_quickStat(context, 'MONTH', Fmt.usd(visibleMonthCost))],
          );
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: primary),
                statsRow,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              primary,
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              statsRow,
            ],
          );
        },
      ),
    );
  }

  Widget _quickStat(BuildContext context, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Palette.muted,
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Palette.ink,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _limitWarning(String text, Future<void> Function(bool) setVisible) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 9, 5, 9),
      decoration: BoxDecoration(
        color: Palette.warning.withValues(alpha: 0.08),
        border: Border.all(color: Palette.warning.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Palette.warning,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Palette.warning,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setVisible(false),
            tooltip: '关闭此类提示，可在设置中重新开启',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: Palette.muted),
          ),
        ],
      ),
    );
  }

  Widget _resetForecast(CodexResetForecast forecast) {
    Widget probability(String label, int value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Palette.muted,
              fontFamily: 'monospace',
              fontSize: 9,
            ),
          ),
          Text(
            '$value%',
            style: const TextStyle(
              color: Palette.signal,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              fontSize: 23,
            ),
          ),
        ],
      );
    }

    return AppCard(
      title: 'Codex 全球重置预测',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              probability('24H', forecast.probability24h),
              const SizedBox(width: 24),
              probability('48H', forecast.probability48h),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (forecast.lastResetAt != null)
                    Text(
                      '上次 ${Fmt.relative(forecast.lastResetAt!)}',
                      style: const TextStyle(
                        color: Palette.muted,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  if (forecast.likelyWindow != null)
                    Text(
                      forecast.likelyWindow!,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'codex-reset.com · 社区预测',
            style: TextStyle(
              color: Palette.muted,
              fontFamily: 'monospace',
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final AppStore store;
  const _EmptyView({required this.store});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.canvas,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppStore.isDesktopRole
                      ? Icons.hourglass_empty
                      : Icons.wifi_find,
                  size: 40,
                  color: Palette.signal,
                ),
                const SizedBox(height: 12),
                Text(
                  store.isRefreshing
                      ? (AppStore.isDesktopRole ? '正在解析本地用量日志…' : '正在寻找桌面端…')
                      : '未连接',
                  style: const TextStyle(
                    color: Palette.ink,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                if (store.syncError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    store.syncError!,
                    style: const TextStyle(
                      color: Palette.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: store.isRefreshing ? null : store.refresh,
                  child: Text(
                    '重新连接',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 显示与连接设置。
class SyncPage extends StatefulWidget {
  final AppStore store;
  const SyncPage({super.key, required this.store});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.store.manualAddress,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(
      key: const PageStorageKey('sync-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          title: '显示',
          child: Column(
            children: [
              _displaySwitch(
                title: '显示 Claude Code 用量',
                value: store.showClaudeUsage,
                onChanged: store.setShowClaudeUsage,
              ),
              _displaySwitch(
                title: '显示 Codex 用量',
                value: store.showCodexUsage,
                onChanged: store.setShowCodexUsage,
              ),
              _displaySwitch(
                title: '显示官方限额缺失提示',
                value: store.showOfficialLimitWarnings,
                onChanged: store.setShowOfficialLimitWarnings,
              ),
              _displaySwitch(
                title: 'Codex 全球重置预测',
                value: store.showCodexResetPrediction,
                onChanged: store.setShowCodexResetPrediction,
              ),
            ],
          ),
        ),
        if (!AppStore.isDesktopRole) ...[
          const SizedBox(height: 12),
          AppCard(
            title: '连接',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '电脑地址，例如 192.168.1.10:48764',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () =>
                          store.saveManualAddress(_controller.text),
                      child: const Text('保存并连接'),
                    ),
                    const SizedBox(width: 10),
                    if (store.manualAddress.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _controller.clear();
                          store.saveManualAddress('');
                        },
                        child: const Text('使用自动发现'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _displaySwitch({
    required String title,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      dense: true,
      title: Text(
        title,
        style: const TextStyle(
          color: Palette.ink,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
