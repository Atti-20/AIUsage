import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class CodexResetForecastClient {
  static Future<CodexResetForecast> fetch() async {
    final resp = await http
        .get(
          Uri.parse('https://codex-reset.com/api/forecast'),
          headers: {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
    final root = (jsonDecode(utf8.decode(resp.bodyBytes)) as Map)
        .cast<String, dynamic>();
    final probabilities = (root['probabilities'] as Map?)?.cast() ?? const {};
    final timeWindow = (root['time_window'] as Map?)?.cast() ?? const {};
    return CodexResetForecast(
      updatedAt: parseDate(root['updated_at']) ?? DateTime.now(),
      probability24h: (probabilities['rounded_24h'] as num?)?.toInt() ?? 0,
      probability48h: (probabilities['rounded_48h'] as num?)?.toInt() ?? 0,
      confidence: root['confidence'] as String? ?? 'low',
      lastResetAt: parseDate(root['last_reset_at']),
      likelyWindow: timeWindow['label'] == null
          ? null
          : '${timeWindow['label']} ${timeWindow['timezone'] ?? 'UTC'}',
    );
  }
}

/// Claude 官方限额（Windows/Linux 上凭据是明文文件 ~/.claude/.credentials.json）。
class ClaudeOAuth {
  static Future<ClaudeLimits> fetch() async {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '.';
    final credFile = File('$home/.claude/.credentials.json');
    if (!credFile.existsSync()) {
      return ClaudeLimits(
        error: '未找到 Claude Code 登录凭据：安装 Claude Code 并登录后即可显示官方限额',
      );
    }
    String? token;
    String? subscription;
    try {
      final j = jsonDecode(credFile.readAsStringSync());
      final oauth = (j as Map)['claudeAiOauth'];
      if (oauth is Map) {
        token = oauth['accessToken'] as String?;
        subscription = oauth['subscriptionType'] as String?;
      }
    } catch (_) {}
    if (token == null) return ClaudeLimits(error: 'Claude 凭据解析失败');

    try {
      final resp = await http
          .get(
            Uri.parse('https://api.anthropic.com/api/oauth/usage'),
            headers: {
              'Authorization': 'Bearer $token',
              'anthropic-beta': 'oauth-2025-04-20',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        return ClaudeLimits(
          subscription: subscription,
          fetchedAt: DateTime.now(),
          error: resp.statusCode == 401
              ? 'Claude 登录令牌已过期，运行一次 claude 即可刷新'
              : 'Claude 限额接口返回 ${resp.statusCode}',
        );
      }
      final root = jsonDecode(resp.body);
      final windows = <LimitWindow>[];
      const known = [
        ('five_hour', '5 小时窗口'),
        ('seven_day', '周限额'),
        ('seven_day_sonnet', 'Sonnet 周限额'),
        ('seven_day_opus', 'Opus 周限额'),
      ];
      for (final (key, label) in known) {
        final w = (root as Map)[key];
        if (w is! Map) continue;
        final raw = (w['utilization'] as num?)?.toDouble();
        if (raw == null) continue;
        final percent = raw <= 1.0 ? raw * 100 : raw;
        DateTime? resetsAt;
        if (w['resets_at'] is String) {
          resetsAt = DateTime.tryParse(w['resets_at'] as String)?.toLocal();
        }
        if (w['resets_at'] is num) {
          resetsAt = DateTime.fromMillisecondsSinceEpoch(
            ((w['resets_at'] as num) * 1000).toInt(),
          );
        }
        windows.add(LimitWindow(key, label, percent, resetsAt, null));
      }
      return ClaudeLimits(
        subscription: subscription,
        windows: windows,
        fetchedAt: DateTime.now(),
        error: windows.isEmpty ? '接口未返回限额窗口' : null,
      );
    } catch (e) {
      return ClaudeLimits(
        subscription: subscription,
        fetchedAt: DateTime.now(),
        error: 'Claude 限额请求失败',
      );
    }
  }
}

/// 局域网快照服务（桌面角色）：HTTP :48764 + UDP 发现应答 :48765。
/// 协议与 Mac 端一致，Android 可同时发现 Mac 或 Windows。
class SnapshotServer {
  static const httpPort = 48764;
  static const discoveryPort = 48765;

  HttpServer? _http;
  RawDatagramSocket? _udp;
  String payload = '{}';
  bool get isRunning => _http != null;

  Future<void> start() async {
    if (_http == null) {
      try {
        final server = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
        server.listen((request) {
          final bytes = utf8.encode(payload);
          request.response
            ..headers.contentType = ContentType(
              'application',
              'json',
              charset: 'utf-8',
            )
            ..headers.set('Access-Control-Allow-Origin', '*')
            ..contentLength = bytes.length
            ..add(bytes);
          request.response.close();
        });
        _http = server;
      } catch (_) {}
    }
    if (_udp == null) {
      try {
        final udp = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
        );
        udp.listen((event) {
          if (event != RawSocketEvent.read) return;
          final dg = udp.receive();
          if (dg == null) return;
          final msg = utf8.decode(dg.data, allowMalformed: true);
          if (!msg.startsWith('AIUSAGE_DISCOVER')) return;
          final reply = utf8.encode(
            'AIUSAGE ${Platform.localHostname} $httpPort',
          );
          udp.send(reply, dg.address, dg.port);
        });
        _udp = udp;
      } catch (_) {}
    }
  }
}

/// 局域网客户端（Android）：UDP 广播发现 + HTTP 拉取。
class LanClient {
  static Future<UsageSnapshot> fetchManual(String address) async {
    var addr = address.trim();
    if (!addr.contains(':')) addr = '$addr:${SnapshotServer.httpPort}';
    final resp = await http
        .get(Uri.parse('http://$addr/snapshot.json'))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
    return UsageSnapshot.fromJson(
      jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// UDP 广播发现桌面端，返回 "ip:port"；找不到抛异常。
  static Future<String> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    try {
      final probe = utf8.encode('AIUSAGE_DISCOVER');
      socket.send(
        probe,
        InternetAddress('255.255.255.255'),
        SnapshotServer.discoveryPort,
      );

      final deadline = DateTime.now().add(timeout);
      await for (final event in socket.timeout(
        timeout,
        onTimeout: (sink) => sink.close(),
      )) {
        if (event != RawSocketEvent.read) continue;
        final dg = socket.receive();
        if (dg == null) continue;
        final msg = utf8.decode(dg.data, allowMalformed: true);
        if (msg.startsWith('AIUSAGE ')) {
          final parts = msg.split(' ');
          final port = parts.length >= 3
              ? parts[2]
              : '${SnapshotServer.httpPort}';
          return '${dg.address.address}:$port';
        }
        if (DateTime.now().isAfter(deadline)) break;
      }
      throw const SocketException('未发现桌面端');
    } finally {
      socket.close();
    }
  }

  static Future<UsageSnapshot> discoverAndFetch() async {
    final addr = await discover();
    return fetchManual(addr);
  }
}
