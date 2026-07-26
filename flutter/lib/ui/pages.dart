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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (store.syncError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(store.syncError!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          _heroCard(context, snapshot),
          const SizedBox(height: 12),
          for (final (source, window) in limits) ...[
            LimitCard(source: source, window: window),
            const SizedBox(height: 12),
          ],
          if (snapshot.claudeLimits?.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(snapshot.claudeLimits!.error!,
                        style: const TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            ),
          AppCard(title: '近 30 天用量趋势', child: TrendChart(days: snapshot.recentDays(30))),
          const SizedBox(height: 12),
          AppCard(title: '模型成本占比', child: ModelDonut(models: snapshot.models)),
          const SizedBox(height: 12),
          AppCard(
            title: '项目排行',
            child: projects.isEmpty
                ? Text('暂无数据', style: Theme.of(context).textTheme.bodySmall)
                : Column(children: [for (final p in projects) ProjectRow(project: p, maxCost: maxCost)]),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('更新于 ${Fmt.dateTime(snapshot.generatedAt)} · 来自 ${snapshot.deviceName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, UsageSnapshot snapshot) {
    final today = snapshot.today;
    final stats = ResetStats.compute(snapshot.resets);
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('今日成本',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(Fmt.usd(today.totalCost),
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [
              SourceChip(source: 'claude', text: Fmt.usd(today.claude.costUSD)),
              SourceChip(source: 'codex', text: Fmt.usd(today.codex.costUSD)),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _quickStat(context, '本月', Fmt.usd(snapshot.monthCost)),
          const SizedBox(height: 10),
          _quickStat(context, '近 90 天', Fmt.usd(snapshot.totalCost)),
          if (stats.lastReset != null) ...[
            const SizedBox(height: 10),
            _quickStat(context, 'Codex 重置', Fmt.relative(stats.lastReset!)),
          ],
        ]),
      ]),
    );
  }

  Widget _quickStat(BuildContext context, String title, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]);
  }
}

class _EmptyView extends StatelessWidget {
  final AppStore store;
  const _EmptyView({required this.store});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppStore.isDesktopRole ? Icons.hourglass_empty : Icons.wifi_find,
            size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(store.isRefreshing ? (AppStore.isDesktopRole ? '正在解析本地用量日志…' : '正在寻找桌面端…') : '暂无数据',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            store.syncError ??
                (AppStore.isDesktopRole
                    ? '将解析本机 ~/.claude 与 ~/.codex 的会话日志'
                    : '在 Mac/Windows 上运行「AI 用量」，并与本机连同一 Wi-Fi'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: store.isRefreshing ? null : store.refresh,
          child: Text(AppStore.isDesktopRole ? '重新解析' : '重新搜索'),
        ),
      ]),
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: _stat(context, '重置总数', '${stats.count}')),
            const SizedBox(width: 12),
            Expanded(child: _stat(context, '平均间隔', stats.averageIntervalDays == null ? '-' : Fmt.days(stats.averageIntervalDays!))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _stat(context, '最长等待', stats.longestIntervalDays == null ? '-' : Fmt.days(stats.longestIntervalDays!))),
            const SizedBox(width: 12),
            Expanded(child: _stat(context, '上次重置', stats.lastReset == null ? '-' : Fmt.relative(stats.lastReset!))),
          ]),
          const SizedBox(height: 12),
          AppCard(
            title: '重置公告（@thsottiaux）',
            child: events.isEmpty
                ? Text('暂无数据，下拉刷新', style: Theme.of(context).textTheme.bodySmall)
                : Column(children: [
                    for (final (i, e) in events.indexed) ...[
                      if (i > 0) const Divider(height: 20),
                      _eventRow(context, e),
                    ],
                  ]),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text('数据来源：codex-resets.com（非官方）',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String title, String value) {
    return AppCard(
      title: title,
      child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }

  Widget _eventRow(BuildContext context, ResetEvent e) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(Fmt.relative(e.announcedAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(width: 8),
        Text(Fmt.dateTime(e.announcedAt),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        if (e.tweetURL.isNotEmpty)
          InkWell(
            onTap: () => launchUrl(Uri.parse(e.tweetURL), mode: LaunchMode.externalApplication),
            child: Text('查看推文', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          ),
      ]),
      const SizedBox(height: 5),
      Text(e.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4)),
    ]);
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
  late final TextEditingController _controller = TextEditingController(text: widget.store.manualAddress);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final snapshot = store.snapshot;
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
        title: '同步状态',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row('数据快照', snapshot == null ? '暂无' : '来自 ${snapshot.deviceName}'),
          if (snapshot != null) _row('生成时间', Fmt.dateTime(snapshot.generatedAt)),
          if (store.lastSyncAt != null) _row('上次同步', Fmt.dateTime(store.lastSyncAt!)),
          if (AppStore.isDesktopRole)
            _row('局域网服务', store.serverRunning ? '运行中（手机可同步本机数据）' : '未运行'),
          if (store.syncError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(store.syncError!, style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: store.isRefreshing ? null : store.refresh,
            child: Text(store.isRefreshing ? '同步中…' : '立即刷新'),
          ),
        ]),
      ),
      if (!AppStore.isDesktopRole) ...[
        const SizedBox(height: 12),
        AppCard(
          title: '手动地址（自动发现失败时）',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: '如 192.168.1.10:48764', isDense: true),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton(
                onPressed: () => store.saveManualAddress(_controller.text),
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
            ]),
          ]),
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
    ]);
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        Flexible(child: Text(value, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
      ]),
    );
  }
}
