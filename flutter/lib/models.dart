/// 数据模型 —— JSON 字段与 Swift 端 UsageSnapshot 完全一致，
/// 保证 Mac/Windows 服务端与 Android 客户端互通。
library;

class TokenTally {
  int input;
  int output;
  int cacheRead;
  int cacheWrite;
  double costUSD;

  TokenTally({
    this.input = 0,
    this.output = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
    this.costUSD = 0,
  });

  int get totalTokens => input + output + cacheRead + cacheWrite;
  bool get isEmpty => totalTokens == 0;

  void add(TokenTally o) {
    input += o.input;
    output += o.output;
    cacheRead += o.cacheRead;
    cacheWrite += o.cacheWrite;
    costUSD += o.costUSD;
  }

  factory TokenTally.fromJson(Map<String, dynamic> j) => TokenTally(
    input: (j['input'] as num?)?.toInt() ?? 0,
    output: (j['output'] as num?)?.toInt() ?? 0,
    cacheRead: (j['cacheRead'] as num?)?.toInt() ?? 0,
    cacheWrite: (j['cacheWrite'] as num?)?.toInt() ?? 0,
    costUSD: (j['costUSD'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'input': input,
    'output': output,
    'cacheRead': cacheRead,
    'cacheWrite': cacheWrite,
    'costUSD': costUSD,
  };
}

class DailyStat {
  String day; // yyyy-MM-dd
  TokenTally claude;
  TokenTally codex;

  DailyStat(this.day, {TokenTally? claude, TokenTally? codex})
    : claude = claude ?? TokenTally(),
      codex = codex ?? TokenTally();

  double get totalCost => claude.costUSD + codex.costUSD;

  double visibleCost({required bool showClaude, required bool showCodex}) =>
      (showClaude ? claude.costUSD : 0) + (showCodex ? codex.costUSD : 0);

  TokenTally tallyFor(String source) => source == 'claude' ? claude : codex;

  factory DailyStat.fromJson(Map<String, dynamic> j) => DailyStat(
    j['day'] as String,
    claude: TokenTally.fromJson((j['claude'] as Map).cast()),
    codex: TokenTally.fromJson((j['codex'] as Map).cast()),
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'claude': claude.toJson(),
    'codex': codex.toJson(),
  };
}

class ModelStat {
  String model;
  String source; // claude / codex
  TokenTally tally;

  ModelStat(this.model, this.source, this.tally);

  factory ModelStat.fromJson(Map<String, dynamic> j) => ModelStat(
    j['model'] as String,
    j['source'] as String,
    TokenTally.fromJson((j['tally'] as Map).cast()),
  );

  Map<String, dynamic> toJson() => {
    'model': model,
    'source': source,
    'tally': tally.toJson(),
  };
}

class ProjectStat {
  String name;
  String path;
  String source;
  TokenTally tally;
  int sessionCount;
  DateTime? lastActivity;

  ProjectStat(
    this.name,
    this.path,
    this.source,
    this.tally,
    this.sessionCount,
    this.lastActivity,
  );

  factory ProjectStat.fromJson(Map<String, dynamic> j) => ProjectStat(
    j['name'] as String,
    j['path'] as String? ?? '',
    j['source'] as String,
    TokenTally.fromJson((j['tally'] as Map).cast()),
    (j['sessionCount'] as num?)?.toInt() ?? 0,
    parseDate(j['lastActivity']),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'source': source,
    'tally': tally.toJson(),
    'sessionCount': sessionCount,
    if (lastActivity != null)
      'lastActivity': lastActivity!.toUtc().toIso8601String(),
  };
}

class SessionStat {
  String sessionID;
  String project;
  String source;
  String? title;
  TokenTally tally;
  DateTime? lastActivity;

  SessionStat(
    this.sessionID,
    this.project,
    this.source,
    this.title,
    this.tally,
    this.lastActivity,
  );

  factory SessionStat.fromJson(Map<String, dynamic> j) => SessionStat(
    j['sessionID'] as String,
    j['project'] as String? ?? '',
    j['source'] as String,
    j['title'] as String?,
    TokenTally.fromJson((j['tally'] as Map).cast()),
    parseDate(j['lastActivity']),
  );

  Map<String, dynamic> toJson() => {
    'sessionID': sessionID,
    'project': project,
    'source': source,
    if (title != null) 'title': title,
    'tally': tally.toJson(),
    if (lastActivity != null)
      'lastActivity': lastActivity!.toUtc().toIso8601String(),
  };
}

class LimitWindow {
  String key;
  String label;
  double utilization; // 0-100
  DateTime? resetsAt;
  int? windowMinutes;

  LimitWindow(
    this.key,
    this.label,
    this.utilization,
    this.resetsAt,
    this.windowMinutes,
  );

  factory LimitWindow.fromJson(Map<String, dynamic> j) => LimitWindow(
    j['key'] as String,
    j['label'] as String,
    (j['utilization'] as num?)?.toDouble() ?? 0,
    parseDate(j['resetsAt']),
    (j['windowMinutes'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'utilization': utilization,
    if (resetsAt != null) 'resetsAt': resetsAt!.toUtc().toIso8601String(),
    if (windowMinutes != null) 'windowMinutes': windowMinutes,
  };
}

class ClaudeLimits {
  String? subscription;
  List<LimitWindow> windows;
  DateTime? fetchedAt;
  String? error;

  ClaudeLimits({
    this.subscription,
    List<LimitWindow>? windows,
    this.fetchedAt,
    this.error,
  }) : windows = windows ?? [];

  factory ClaudeLimits.fromJson(Map<String, dynamic> j) => ClaudeLimits(
    subscription: j['subscription'] as String?,
    windows: ((j['windows'] as List?) ?? [])
        .map((e) => LimitWindow.fromJson((e as Map).cast()))
        .toList(),
    fetchedAt: parseDate(j['fetchedAt']),
    error: j['error'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (subscription != null) 'subscription': subscription,
    'windows': windows.map((w) => w.toJson()).toList(),
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toUtc().toIso8601String(),
    if (error != null) 'error': error,
  };
}

class CodexLimits {
  String? plan;
  List<LimitWindow> windows;
  String? creditsBalance;
  DateTime? capturedAt;

  CodexLimits({
    this.plan,
    List<LimitWindow>? windows,
    this.creditsBalance,
    this.capturedAt,
  }) : windows = windows ?? [];

  factory CodexLimits.fromJson(Map<String, dynamic> j) => CodexLimits(
    plan: j['plan'] as String?,
    windows: ((j['windows'] as List?) ?? [])
        .map((e) => LimitWindow.fromJson((e as Map).cast()))
        .toList(),
    creditsBalance: j['creditsBalance'] as String?,
    capturedAt: parseDate(j['capturedAt']),
  );

  Map<String, dynamic> toJson() => {
    if (plan != null) 'plan': plan,
    'windows': windows.map((w) => w.toJson()).toList(),
    if (creditsBalance != null) 'creditsBalance': creditsBalance,
    if (capturedAt != null) 'capturedAt': capturedAt!.toUtc().toIso8601String(),
  };
}

class CodexResetForecast {
  DateTime updatedAt;
  int probability24h;
  int probability48h;
  String confidence;
  DateTime? lastResetAt;
  String? likelyWindow;

  CodexResetForecast({
    required this.updatedAt,
    required this.probability24h,
    required this.probability48h,
    required this.confidence,
    this.lastResetAt,
    this.likelyWindow,
  });

  factory CodexResetForecast.fromJson(Map<String, dynamic> j) =>
      CodexResetForecast(
        updatedAt: parseDate(j['updated_at']) ?? DateTime.now(),
        probability24h: (j['probability_24h'] as num?)?.toInt() ?? 0,
        probability48h: (j['probability_48h'] as num?)?.toInt() ?? 0,
        confidence: j['confidence'] as String? ?? 'low',
        lastResetAt: parseDate(j['last_reset_at']),
        likelyWindow: j['likely_window'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'probability_24h': probability24h,
    'probability_48h': probability48h,
    'confidence': confidence,
    if (lastResetAt != null)
      'last_reset_at': lastResetAt!.toUtc().toIso8601String(),
    if (likelyWindow != null) 'likely_window': likelyWindow,
  };
}

class ResetEvent {
  String tweetID;
  String tweetURL;
  String text;
  DateTime announcedAt;

  ResetEvent(this.tweetID, this.tweetURL, this.text, this.announcedAt);

  factory ResetEvent.fromJson(Map<String, dynamic> j) => ResetEvent(
    j['tweet_id'] as String,
    j['tweet_url'] as String? ?? '',
    j['text'] as String? ?? '',
    parseDate(j['announced_at']) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'tweet_id': tweetID,
    'tweet_url': tweetURL,
    'text': text,
    'announced_at': announcedAt.toUtc().toIso8601String(),
  };
}

class ResetStats {
  int count;
  double? averageIntervalDays;
  double? longestIntervalDays;
  DateTime? lastReset;

  ResetStats(
    this.count,
    this.averageIntervalDays,
    this.longestIntervalDays,
    this.lastReset,
  );

  static ResetStats compute(List<ResetEvent> events) {
    final sorted = events.map((e) => e.announcedAt).toList()..sort();
    if (sorted.isEmpty) return ResetStats(0, null, null, null);
    final intervals = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      intervals.add(sorted[i].difference(sorted[i - 1]).inSeconds / 86400.0);
    }
    final avg = intervals.isEmpty
        ? null
        : intervals.reduce((a, b) => a + b) / intervals.length;
    final max = intervals.isEmpty
        ? null
        : intervals.reduce((a, b) => a > b ? a : b);
    return ResetStats(sorted.length, avg, max, sorted.last);
  }
}

class UsageSnapshot {
  DateTime generatedAt;
  String deviceName;
  List<DailyStat> days;
  List<ModelStat> models;
  List<ProjectStat> projects;
  List<SessionStat> sessions;
  ClaudeLimits? claudeLimits;
  CodexLimits? codexLimits;
  CodexResetForecast? codexResetForecast;
  List<ResetEvent> resets;

  UsageSnapshot({
    required this.generatedAt,
    required this.deviceName,
    List<DailyStat>? days,
    List<ModelStat>? models,
    List<ProjectStat>? projects,
    List<SessionStat>? sessions,
    this.claudeLimits,
    this.codexLimits,
    this.codexResetForecast,
    List<ResetEvent>? resets,
  }) : days = days ?? [],
       models = models ?? [],
       projects = projects ?? [],
       sessions = sessions ?? [],
       resets = resets ?? [];

  factory UsageSnapshot.fromJson(Map<String, dynamic> j) => UsageSnapshot(
    generatedAt: parseDate(j['generatedAt']) ?? DateTime.now(),
    deviceName: j['deviceName'] as String? ?? '',
    days: ((j['days'] as List?) ?? [])
        .map((e) => DailyStat.fromJson((e as Map).cast()))
        .toList(),
    models: ((j['models'] as List?) ?? [])
        .map((e) => ModelStat.fromJson((e as Map).cast()))
        .toList(),
    projects: ((j['projects'] as List?) ?? [])
        .map((e) => ProjectStat.fromJson((e as Map).cast()))
        .toList(),
    sessions: ((j['sessions'] as List?) ?? [])
        .map((e) => SessionStat.fromJson((e as Map).cast()))
        .toList(),
    claudeLimits: j['claudeLimits'] == null
        ? null
        : ClaudeLimits.fromJson((j['claudeLimits'] as Map).cast()),
    codexLimits: j['codexLimits'] == null
        ? null
        : CodexLimits.fromJson((j['codexLimits'] as Map).cast()),
    codexResetForecast: j['codexResetForecast'] == null
        ? null
        : CodexResetForecast.fromJson((j['codexResetForecast'] as Map).cast()),
    resets: ((j['resets'] as List?) ?? [])
        .map((e) => ResetEvent.fromJson((e as Map).cast()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'deviceName': deviceName,
    'days': days.map((d) => d.toJson()).toList(),
    'models': models.map((m) => m.toJson()).toList(),
    'projects': projects.map((p) => p.toJson()).toList(),
    'sessions': sessions.map((s) => s.toJson()).toList(),
    if (claudeLimits != null) 'claudeLimits': claudeLimits!.toJson(),
    if (codexLimits != null) 'codexLimits': codexLimits!.toJson(),
    if (codexResetForecast != null)
      'codexResetForecast': codexResetForecast!.toJson(),
    'resets': resets.map((r) => r.toJson()).toList(),
  };

  DailyStat get today {
    final key = dayKey(DateTime.now());
    return days.where((d) => d.day == key).firstOrNull ?? DailyStat(key);
  }

  double get monthCost {
    final prefix = dayKey(DateTime.now()).substring(0, 7);
    return days
        .where((d) => d.day.startsWith(prefix))
        .fold(0.0, (s, d) => s + d.totalCost);
  }

  double get totalCost => days.fold(0.0, (s, d) => s + d.totalCost);

  double visibleMonthCost({required bool showClaude, required bool showCodex}) {
    final prefix = dayKey(DateTime.now()).substring(0, 7);
    return days
        .where((d) => d.day.startsWith(prefix))
        .fold(
          0.0,
          (sum, day) =>
              sum +
              day.visibleCost(showClaude: showClaude, showCodex: showCodex),
        );
  }

  double visibleTotalCost({
    required bool showClaude,
    required bool showCodex,
  }) => days.fold(
    0.0,
    (sum, day) =>
        sum + day.visibleCost(showClaude: showClaude, showCodex: showCodex),
  );

  bool isSourceVisible(
    String source, {
    required bool showClaude,
    required bool showCodex,
  }) => source == 'claude' ? showClaude : showCodex;

  List<ProjectStat> visibleProjects({
    required bool showClaude,
    required bool showCodex,
  }) {
    final visible = projects
        .where(
          (project) => isSourceVisible(
            project.source,
            showClaude: showClaude,
            showCodex: showCodex,
          ),
        )
        .toList();
    visible.sort((left, right) {
      final byCost = right.tally.costUSD.compareTo(left.tally.costUSD);
      if (byCost != 0) return byCost;
      return right.tally.totalTokens.compareTo(left.tally.totalTokens);
    });
    return visible;
  }

  List<DailyStat> recentDays(int n) =>
      days.length <= n ? days : days.sublist(days.length - n);

  List<(String, LimitWindow)> get allLimitWindows => [
    for (final w in claudeLimits?.windows ?? <LimitWindow>[]) ('claude', w),
    for (final w in codexLimits?.windows ?? <LimitWindow>[]) ('codex', w),
  ];
}

DateTime? parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch((v * 1000).toInt()).toLocal();
  }
  return null;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
