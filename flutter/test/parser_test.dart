import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aiusage/models.dart';
import 'package:aiusage/parsers.dart';
import 'package:aiusage/pricing.dart';

void main() {
  test('快照 JSON 序列化往返一致', () {
    final snap = UsageSnapshot(generatedAt: DateTime.now(), deviceName: 'test')
      ..days.add(
        DailyStat(
          '2026-07-26',
          claude: TokenTally(
            input: 10,
            output: 20,
            cacheRead: 30,
            cacheWrite: 40,
            costUSD: 1.5,
          ),
        ),
      )
      ..models.add(
        ModelStat(
          'claude-fable-5',
          'claude',
          TokenTally(input: 10, costUSD: 0.1),
        ),
      )
      ..codexResetForecast = CodexResetForecast(
        updatedAt: DateTime.now(),
        probability24h: 15,
        probability48h: 30,
        confidence: 'medium',
        lastResetAt: DateTime.now().subtract(const Duration(days: 1)),
        likelyWindow: '3 AM - 6 AM UTC',
      );
    final round = UsageSnapshot.fromJson(
      jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>,
    );
    expect(round.days.single.claude.totalTokens, 100);
    expect(round.days.single.claude.costUSD, 1.5);
    expect(round.models.single.model, 'claude-fable-5');
    expect(round.codexResetForecast?.probability48h, 30);
  });

  test('定价：内置表匹配', () {
    final p = Pricing.shared;
    expect(p.cost('claude-fable-5', TokenTally(output: 1000000)), 50);
    expect(p.cost('gpt-5.1-codex', TokenTally(cacheRead: 1000000)), 0.125);
  });

  test('显示来源筛选只汇总已启用的用量', () {
    final day = DailyStat(
      dayKey(DateTime.now()),
      claude: TokenTally(costUSD: 3),
      codex: TokenTally(costUSD: 7),
    );
    final snap = UsageSnapshot(
      generatedAt: DateTime.now(),
      deviceName: 'test',
      days: [day],
    );

    expect(day.visibleCost(showClaude: true, showCodex: false), 3);
    expect(day.visibleCost(showClaude: false, showCodex: true), 7);
    expect(snap.visibleMonthCost(showClaude: false, showCodex: false), 0);
    expect(snap.visibleTotalCost(showClaude: true, showCodex: true), 10);
  });

  test('项目用量排名遵循来源开关并按成本排序', () {
    final snap = UsageSnapshot(
      generatedAt: DateTime.now(),
      deviceName: 'test',
      projects: [
        ProjectStat(
          'Claude Project',
          '/claude',
          'claude',
          TokenTally(costUSD: 8),
          2,
          null,
        ),
        ProjectStat(
          'Codex Project',
          '/codex',
          'codex',
          TokenTally(costUSD: 12),
          3,
          null,
        ),
      ],
    );

    expect(
      snap
          .visibleProjects(showClaude: true, showCodex: true)
          .map((project) => project.name),
      ['Codex Project', 'Claude Project'],
    );
    expect(
      snap.visibleProjects(showClaude: true, showCodex: false).single.name,
      'Claude Project',
    );
  });

  test('Codex 5 小时与周度窗口保持并行显示', () {
    expect(LocalParser.windowLabel(300, '主限额'), '5 小时窗口');
    expect(LocalParser.windowLabel(10080, '次限额'), '周限额');

    final snap = UsageSnapshot(
      generatedAt: DateTime.now(),
      deviceName: 'test',
      codexLimits: CodexLimits(
        windows: [
          LimitWindow('primary', '5 小时窗口', 20, DateTime.now(), 300),
          LimitWindow('secondary', '周限额', 35, DateTime.now(), 10080),
        ],
      ),
    );
    expect(snap.allLimitWindows.map((item) => item.$2.label), [
      '5 小时窗口',
      '周限额',
    ]);
  });

  test('本地日志解析（存在本机数据时）', () async {
    final home = Platform.environment['HOME'] ?? '';
    if (!Directory('$home/.claude/projects').existsSync() &&
        !Directory('$home/.codex/sessions').existsSync()) {
      return; // CI 上无数据，跳过
    }
    final snap = await LocalParser(Pricing.shared).parseAll();
    // 至少解析出一些天数与会话，且成本非负
    expect(snap.days, isNotEmpty);
    for (final d in snap.days) {
      expect(d.totalCost, greaterThanOrEqualTo(0));
    }
    stdout.writeln(
      'parsed days=${snap.days.length} '
      'todayCost=${snap.today.totalCost.toStringAsFixed(2)} '
      'models=${snap.models.length} projects=${snap.projects.length} '
      'codexPlan=${snap.codexLimits?.plan}',
    );
  });
}
