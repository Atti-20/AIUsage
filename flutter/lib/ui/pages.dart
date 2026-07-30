import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final limits = snapshot.allLimitWindows;
    final projects = snapshot.projects.take(6).toList();
    final maxCost = projects.isEmpty ? 0.0 : projects.first.tally.costUSD;

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
          _pageHeader(context),
          const SizedBox(height: 22),
          if (limits.isNotEmpty) ...[
            const TerminalEyebrow(text: 'active limit windows'),
            const SizedBox(height: 10),
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
          if (snapshot.claudeLimits?.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Palette.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      snapshot.claudeLimits!.error!,
                      style: const TextStyle(
                        color: Palette.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _costHero(context, snapshot),
          const SizedBox(height: 12),
          AppCard(
            title: '30 day usage signal',
            child: TrendChart(days: snapshot.recentDays(30)),
          ),
          const SizedBox(height: 12),
          AppCard(
            title: 'model cost share',
            child: ModelDonut(models: snapshot.models),
          ),
          const SizedBox(height: 12),
          AppCard(
            title: 'top projects',
            child: projects.isEmpty
                ? Text('暂无数据', style: Theme.of(context).textTheme.bodySmall)
                : Column(
                    children: [
                      for (final p in projects)
                        ProjectRow(project: p, maxCost: maxCost),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '更新于 ${Fmt.dateTime(snapshot.generatedAt)} · 来自 ${snapshot.deviceName}',
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

  Widget _pageHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            TerminalEyebrow(text: 'usage monitor / local'),
            Spacer(),
            StatusPill(text: 'LIVE SNAPSHOT'),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '额度还够用吗？',
          style: TextStyle(
            color: Palette.ink,
            fontFamily: 'monospace',
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Claude Code 与 Codex 的限额、重置时间和本地成本汇总。原始会话始终留在你的设备上。',
          style: TextStyle(color: Palette.muted, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _costHero(BuildContext context, UsageSnapshot snapshot) {
    final today = snapshot.today;
    final stats = ResetStats.compute(snapshot.resets);
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 580;
          final primary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TerminalEyebrow(text: 'today / estimated cost'),
              const SizedBox(height: 8),
              Text(
                Fmt.usd(today.totalCost),
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
                  SourceChip(
                    source: 'claude',
                    text: Fmt.usd(today.claude.costUSD),
                  ),
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
            children: [
              _quickStat(context, 'MONTH', Fmt.usd(snapshot.monthCost)),
              _quickStat(context, '90 DAYS', Fmt.usd(snapshot.totalCost)),
              if (stats.lastReset != null)
                _quickStat(
                  context,
                  'GLOBAL RESET',
                  Fmt.relative(stats.lastReset!),
                ),
            ],
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
                const TerminalEyebrow(text: 'waiting for usage data'),
                const SizedBox(height: 18),
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
                      : '暂无数据',
                  style: const TextStyle(
                    color: Palette.ink,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  store.syncError ??
                      (AppStore.isDesktopRole
                          ? '将解析本机 ~/.claude 与 ~/.codex 的会话日志'
                          : '在 Mac/Windows 上运行「AI 用量」，并与本机连同一 Wi-Fi'),
                  style: const TextStyle(
                    color: Palette.muted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: store.isRefreshing ? null : store.refresh,
                  child: Text(
                    AppStore.isDesktopRole
                        ? '> REPARSE LOGS'
                        : '> RETRY DISCOVERY',
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

/// codex-resets.com 重置动态页。
class ResetsPage extends StatelessWidget {
  final AppStore store;
  const ResetsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final events = store.resets;
    final stats = ResetStats.compute(events);
    return RefreshIndicator(
      onRefresh: store.refresh,
      child: ListView(
        key: const PageStorageKey('resets-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const TerminalEyebrow(text: 'global reset signal'),
                    const Spacer(),
                    StatusPill(
                      text: events.isEmpty ? 'CHECKING FEED' : 'FEED ONLINE',
                      isLive: events.isNotEmpty,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  stats.lastReset == null
                      ? '尚无重置信号'
                      : Fmt.relative(stats.lastReset!),
                  style: const TextStyle(
                    color: Palette.signal,
                    fontFamily: 'monospace',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stats.lastReset == null
                      ? '联网后会自动加载社区记录的全局重置动态。'
                      : '最近一次已验证的全局重置：${Fmt.dateTime(stats.lastReset!)}',
                  style: const TextStyle(color: Palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat(context, 'VERIFIED RESETS', '${stats.count}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stat(
                  context,
                  'AVERAGE GAP',
                  stats.averageIntervalDays == null
                      ? '-'
                      : Fmt.days(stats.averageIntervalDays!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  'LONGEST WAIT',
                  stats.longestIntervalDays == null
                      ? '-'
                      : Fmt.days(stats.longestIntervalDays!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stat(
                  context,
                  'LAST SIGNAL',
                  stats.lastReset == null
                      ? '-'
                      : Fmt.relative(stats.lastReset!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            title: 'verified reset timeline',
            child: events.isEmpty
                ? Text(
                    '暂无数据，下拉刷新',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final (i, e) in events.indexed) ...[
                        if (i > 0) const Divider(height: 20),
                        _eventRow(context, e),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Center(
            child: const Text(
              'SOURCE / codex-resets.com · 非官方社区信号',
              style: TextStyle(
                color: Palette.muted,
                fontFamily: 'monospace',
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String title, String value) {
    return AppCard(
      title: title,
      child: Text(
        value,
        style: const TextStyle(
          color: Palette.ink,
          fontFamily: 'monospace',
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _eventRow(BuildContext context, ResetEvent e) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              Fmt.relative(e.announcedAt).toUpperCase(),
              style: const TextStyle(
                color: Palette.signal,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Fmt.dateTime(e.announcedAt),
              style: const TextStyle(
                color: Palette.muted,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
            const Spacer(),
            if (e.tweetURL.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse(e.tweetURL),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text(
                  'SOURCE ↗',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Palette.signal,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          e.text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    );
  }
}

/// 同步 / 设置页。
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
    final snapshot = store.snapshot;
    return ListView(
      key: const PageStorageKey('sync-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          title: '同步状态',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(
                '数据快照',
                snapshot == null ? '暂无' : '来自 ${snapshot.deviceName}',
              ),
              if (snapshot != null)
                _row('生成时间', Fmt.dateTime(snapshot.generatedAt)),
              if (store.lastSyncAt != null)
                _row('上次同步', Fmt.dateTime(store.lastSyncAt!)),
              if (AppStore.isDesktopRole)
                _row('局域网服务', store.serverRunning ? '运行中（手机可同步本机数据）' : '未运行'),
              if (store.syncError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    store.syncError!,
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: store.isRefreshing ? null : store.refresh,
                child: Text(store.isRefreshing ? '同步中…' : '立即刷新'),
              ),
            ],
          ),
        ),
        if (!AppStore.isDesktopRole) ...[
          const SizedBox(height: 12),
          AppCard(
            title: '手动地址（自动发现失败时）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '如 192.168.1.10:48764',
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
                        child: const Text('清除，改用自动发现'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        AppCard(
          title: '说明',
          child: Text(
            AppStore.isDesktopRole
                ? '本机解析 ~/.claude 与 ~/.codex 的会话日志，成本按各模型 API 定价估算（订阅套餐实际不另计费）。'
                      '本机同时提供局域网只读服务（端口 48764），Android 端可自动发现同步。'
                : '用量数据来自局域网内的 Mac/Windows「AI 用量」，离线时显示上次缓存；重置动态独立在线刷新。',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
