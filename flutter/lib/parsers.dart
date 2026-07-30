import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'pricing.dart';

/// 本地日志解析（Windows / macOS 桌面角色）。
/// 逻辑与 Swift 版一致：
/// - Claude：~/.claude/projects/**/*.jsonl，按 message.id+requestId 全局去重
/// - Codex：~/.codex/sessions/**/*.jsonl，token_count 累计值做差 + rate_limits 快照
class LocalParser {
  static const keepDays = 90;

  final Pricing pricing;
  LocalParser(this.pricing);

  static String get home =>
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      '.';

  Future<UsageSnapshot> parseAll() async {
    final b = _Builder();
    _parseClaude(b);
    _parseCodex(b);
    return b.build(deviceName: Platform.localHostname);
  }

  // MARK: Claude

  void _parseClaude(_Builder b) {
    final root = Directory('$home/.claude/projects');
    if (!root.existsSync()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays + 2));
    final seen = <String>{};
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
      try {
        if (entity.lastModifiedSync().isBefore(cutoff)) continue;
        _parseClaudeFile(entity, b, seen);
      } catch (_) {}
    }
  }

  void _parseClaudeFile(File file, _Builder b, Set<String> seen) {
    final sessionTally = TokenTally();
    var projectPath = '';
    String? title;
    DateTime? lastActivity;

    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> obj;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        obj = decoded;
      } catch (_) {
        continue;
      }
      final type = obj['type'];
      if (projectPath.isEmpty && obj['cwd'] is String) {
        projectPath = obj['cwd'] as String;
      }
      if (type == 'summary' &&
          obj['summary'] is String &&
          (obj['summary'] as String).isNotEmpty) {
        title = obj['summary'] as String;
        continue;
      }
      if (type != 'assistant') continue;
      final message = obj['message'];
      if (message is! Map) continue;
      final usage = message['usage'];
      if (usage is! Map) continue;
      final model = message['model'] as String? ?? 'unknown';
      if (model == '<synthetic>') continue;

      final msgID = message['id'] as String? ?? '';
      final reqID = obj['requestId'] as String? ?? '';
      if (msgID.isNotEmpty || reqID.isNotEmpty) {
        final key = '$msgID|$reqID';
        if (seen.contains(key)) continue;
        seen.add(key);
      }

      final tally = TokenTally(
        input: (usage['input_tokens'] as num?)?.toInt() ?? 0,
        output: (usage['output_tokens'] as num?)?.toInt() ?? 0,
        cacheRead: (usage['cache_read_input_tokens'] as num?)?.toInt() ?? 0,
        cacheWrite:
            (usage['cache_creation_input_tokens'] as num?)?.toInt() ?? 0,
      );
      tally.costUSD =
          (obj['costUSD'] as num?)?.toDouble() ?? pricing.cost(model, tally);

      final date = parseDate(obj['timestamp']) ?? DateTime.now();
      if (lastActivity == null || date.isAfter(lastActivity)) {
        lastActivity = date;
      }

      b.add(dayKey(date), 'claude', model, tally);
      sessionTally.add(tally);
    }

    if (sessionTally.isEmpty) return;
    final sessionID = file.uri.pathSegments.last.replaceAll('.jsonl', '');
    final projectName = projectPath.isEmpty
        ? '未知项目'
        : projectPath.split(Platform.pathSeparator).last.split('/').last;
    b.addSession(
      SessionStat(
        sessionID,
        projectName,
        'claude',
        title,
        sessionTally,
        lastActivity,
      ),
      projectPath,
    );
  }

  // MARK: Codex

  void _parseCodex(_Builder b) {
    final cutoff = DateTime.now().subtract(const Duration(days: keepDays + 2));
    for (final rootPath in [
      '$home/.codex/sessions',
      '$home/.codex/archived_sessions',
    ]) {
      final root = Directory(rootPath);
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
        try {
          if (entity.lastModifiedSync().isBefore(cutoff)) continue;
          _parseCodexFile(entity, b);
        } catch (_) {}
      }
    }
  }

  void _parseCodexFile(File file, _Builder b) {
    var projectPath = '';
    var sessionID = file.uri.pathSegments.last.replaceAll('.jsonl', '');
    String? model;
    var prev = _Totals();
    var last = _Totals();
    DateTime? lastActivity;
    var sessionCost = 0.0;

    for (final line in file.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      Map<String, dynamic> obj;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map<String, dynamic>) continue;
        obj = decoded;
      } catch (_) {
        continue;
      }
      final payload = obj['payload'];
      if (payload is! Map) continue;
      final type = obj['type'];
      final timestamp = parseDate(obj['timestamp']);

      if (type == 'session_meta') {
        if (payload['cwd'] is String) projectPath = payload['cwd'] as String;
        if (payload['id'] is String) sessionID = payload['id'] as String;
        if (payload['model'] is String) model = payload['model'] as String;
      } else if (type == 'turn_context') {
        if (payload['model'] is String) model = payload['model'] as String;
        if (projectPath.isEmpty && payload['cwd'] is String) {
          projectPath = payload['cwd'] as String;
        }
      } else if (type == 'event_msg' && payload['type'] == 'token_count') {
        final info = payload['info'];
        if (info is Map && info['total_token_usage'] is Map) {
          final current = _Totals.from(
            (info['total_token_usage'] as Map).cast(),
          );
          final delta = current.delta(prev);
          prev = current;
          last = current;
          if (!delta.isEmpty) {
            final date = timestamp ?? DateTime.now();
            if (lastActivity == null || date.isAfter(lastActivity)) {
              lastActivity = date;
            }
            delta.costUSD = pricing.cost(model ?? 'gpt-5', delta);
            sessionCost += delta.costUSD;
            b.add(dayKey(date), 'codex', model ?? 'gpt-5', delta);
          }
        }
        final rl = payload['rate_limits'];
        if (rl is Map) {
          final cap = _captureRateLimits(
            rl.cast(),
            timestamp ?? DateTime.now(),
          );
          if (cap != null &&
              (b.codexCapturedAt == null ||
                  cap.$1.isAfter(b.codexCapturedAt!))) {
            b.codexCapturedAt = cap.$1;
            b.codexLimits = cap.$2;
          }
        }
      }
    }

    final sessionTally = last.tally..costUSD = sessionCost;
    if (sessionTally.isEmpty) return;
    final projectName = projectPath.isEmpty
        ? '未知项目'
        : projectPath.split(Platform.pathSeparator).last.split('/').last;
    b.addSession(
      SessionStat(
        sessionID,
        projectName,
        'codex',
        null,
        sessionTally,
        lastActivity,
      ),
      projectPath,
    );
  }

  (DateTime, CodexLimits)? _captureRateLimits(
    Map<String, dynamic> rl,
    DateTime at,
  ) {
    final limitID = rl['limit_id'];
    if (limitID is String && limitID != 'codex') return null;
    final windows = <LimitWindow>[];
    for (final (key, fallback) in [('primary', '主限额'), ('secondary', '次限额')]) {
      final w = rl[key];
      if (w is! Map) continue;
      final used = (w['used_percent'] as num?)?.toDouble();
      if (used == null) continue;
      final minutes = (w['window_minutes'] as num?)?.toInt();
      DateTime? resetsAt;
      if (w['resets_at'] is num) {
        resetsAt = DateTime.fromMillisecondsSinceEpoch(
          ((w['resets_at'] as num) * 1000).toInt(),
        );
      } else if (w['resets_in_seconds'] is num) {
        resetsAt = at.add(
          Duration(seconds: (w['resets_in_seconds'] as num).toInt()),
        );
      }
      windows.add(
        LimitWindow(
          key,
          windowLabel(minutes, fallback),
          used,
          resetsAt,
          minutes,
        ),
      );
    }
    if (windows.isEmpty) return null;
    String? balance;
    final credits = rl['credits'];
    if (credits is Map) {
      if (credits['unlimited'] == true) {
        balance = '不限量';
      } else if (credits['balance'] is String && credits['balance'] != '0') {
        balance = credits['balance'] as String;
      }
    }
    return (
      at,
      CodexLimits(
        plan: rl['plan_type'] as String?,
        windows: windows,
        creditsBalance: balance,
        capturedAt: at,
      ),
    );
  }

  static String windowLabel(int? minutes, String fallback) {
    if (minutes == null) return fallback;
    if (minutes < 120) return '$minutes 分钟窗口';
    if (minutes < 2880) return '${minutes ~/ 60} 小时窗口';
    if (minutes >= 9000 && minutes <= 11000) return '周限额';
    return '${minutes ~/ 1440} 天窗口';
  }
}

class _Totals {
  int input = 0, cached = 0, cacheWrite = 0, output = 0;

  _Totals();

  factory _Totals.from(Map<String, dynamic> d) {
    final t = _Totals();
    t.input = (d['input_tokens'] as num?)?.toInt() ?? 0;
    t.cached = (d['cached_input_tokens'] as num?)?.toInt() ?? 0;
    t.cacheWrite = (d['cache_write_input_tokens'] as num?)?.toInt() ?? 0;
    t.output = (d['output_tokens'] as num?)?.toInt() ?? 0;
    return t;
  }

  TokenTally get tally => TokenTally(
    input: (input - cached).clamp(0, 1 << 62),
    cacheRead: cached,
    cacheWrite: cacheWrite,
    output: output,
  );

  TokenTally delta(_Totals prev) {
    final dInput = (input - prev.input).clamp(0, 1 << 62);
    final dCached = (cached - prev.cached).clamp(0, 1 << 62);
    return TokenTally(
      input: (dInput - dCached).clamp(0, 1 << 62),
      cacheRead: dCached,
      cacheWrite: (cacheWrite - prev.cacheWrite).clamp(0, 1 << 62),
      output: (output - prev.output).clamp(0, 1 << 62),
    );
  }
}

class _Builder {
  final perDay = <String, DailyStat>{};
  final perModel = <String, ModelStat>{};
  final perProject = <String, ProjectStat>{};
  final sessions = <SessionStat>[];
  CodexLimits? codexLimits;
  DateTime? codexCapturedAt;

  late final String cutoffKey = dayKey(
    DateTime.now().subtract(const Duration(days: LocalParser.keepDays)),
  );

  void add(String day, String source, String model, TokenTally tally) {
    if (day.compareTo(cutoffKey) < 0) return;
    final d = perDay.putIfAbsent(day, () => DailyStat(day));
    (source == 'claude' ? d.claude : d.codex).add(tally);
    final m = perModel.putIfAbsent(
      '$source|$model',
      () => ModelStat(model, source, TokenTally()),
    );
    m.tally.add(tally);
  }

  void addSession(SessionStat session, String projectPath) {
    if (session.tally.isEmpty) return;
    sessions.add(session);
    final p = perProject.putIfAbsent(
      '${session.source}|$projectPath',
      () => ProjectStat(
        session.project,
        projectPath,
        session.source,
        TokenTally(),
        0,
        null,
      ),
    );
    p.tally.add(session.tally);
    p.sessionCount += 1;
    final a = session.lastActivity;
    if (a != null && (p.lastActivity == null || a.isAfter(p.lastActivity!))) {
      p.lastActivity = a;
    }
  }

  UsageSnapshot build({required String deviceName}) {
    final days = perDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    final models = perModel.values.toList()
      ..sort((a, b) => b.tally.costUSD.compareTo(a.tally.costUSD));
    final projects = perProject.values.toList()
      ..sort((a, b) => b.tally.costUSD.compareTo(a.tally.costUSD));
    sessions.sort(
      (a, b) => (b.lastActivity ?? DateTime(2000)).compareTo(
        a.lastActivity ?? DateTime(2000),
      ),
    );
    return UsageSnapshot(
      generatedAt: DateTime.now(),
      deviceName: deviceName,
      days: days,
      models: models,
      projects: projects.take(30).toList(),
      sessions: sessions.take(50).toList(),
      codexLimits: codexLimits,
    );
  }
}
