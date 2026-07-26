import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aiusage/models.dart';
import 'package:aiusage/parsers.dart';
import 'package:aiusage/pricing.dart';

void main() {
  test('快照 JSON 序列化往返一致', () {
    final snap = UsageSnapshot(generatedAt: DateTime.now(), deviceName: 'test')
      ..days.add(DailyStat('2026-07-26',
          claude: TokenTally(input: 10, output: 20, cacheRead: 30, cacheWrite: 40, costUSD: 1.5)))
      ..models.add(ModelStat('claude-fable-5', 'claude', TokenTally(input: 10, costUSD: 0.1)))
      ..resets.add(ResetEvent('1', 'https://x.com/x/1', 'reset!', DateTime.now()));
    final round = UsageSnapshot.fromJson(jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>);
    expect(round.days.single.claude.totalTokens, 100);
    expect(round.days.single.claude.costUSD, 1.5);
    expect(round.models.single.model, 'claude-fable-5');
    expect(round.resets.single.tweetID, '1');
  });

  test('定价：内置表匹配', () {
    final p = Pricing.shared;
    expect(p.cost('claude-fable-5', TokenTally(output: 1000000)), 50);
    expect(p.cost('gpt-5.1-codex', TokenTally(cacheRead: 1000000)), 0.125);
  });

  test('本地日志解析（存在本机数据时）', () async {
    final home = Platform.environment['HOME'] ?? '';
    if (!Directory('$home/.claude/projects').existsSync() && !Directory('$home/.codex/sessions').existsSync()) {
      return; // CI 上无数据，跳过
    }
    final snap = await LocalParser(Pricing.shared).parseAll();
    // 至少解析出一些天数与会话，且成本非负
    expect(snap.days, isNotEmpty);
    for (final d in snap.days) {
      expect(d.totalCost, greaterThanOrEqualTo(0));
    }
    stdout.writeln('parsed days=${snap.days.length} '
        'todayCost=${snap.today.totalCost.toStringAsFixed(2)} '
        'models=${snap.models.length} projects=${snap.projects.length} '
        'codexPlan=${snap.codexLimits?.plan}');
  });
}
