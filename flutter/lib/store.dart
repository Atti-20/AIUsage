import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'net.dart';
import 'parsers.dart';
import 'pricing.dart';

/// 应用数据中枢。
/// 桌面角色（Windows/macOS/Linux）：本地解析 + 官方限额 + 重置动态 + 局域网服务。
/// 移动角色（Android）：局域网发现/手动地址拉取 + 本地缓存 + 重置动态。
class AppStore extends ChangeNotifier {
  static bool get isDesktopRole => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  UsageSnapshot? snapshot;
  List<ResetEvent>? freshResets;
  bool isRefreshing = false;
  String? syncError;
  DateTime? lastSyncAt;
  String manualAddress = '';
  bool serverRunning = false;

  final _server = SnapshotServer();
  Timer? _timer;
  SharedPreferences? _prefs;

  List<ResetEvent> get resets => freshResets ?? snapshot?.resets ?? [];

  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    manualAddress = _prefs?.getString('manualAddress') ?? '';
    final cached = _prefs?.getString('snapshotCache');
    if (cached != null) {
      try {
        snapshot = UsageSnapshot.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      } catch (_) {}
    }
    notifyListeners();
    await refresh();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> saveManualAddress(String address) async {
    manualAddress = address.trim();
    await _prefs?.setString('manualAddress', manualAddress);
    await refresh();
  }

  Future<void> refresh() async {
    if (isRefreshing) return;
    isRefreshing = true;
    syncError = null;
    notifyListeners();

    try {
      if (isDesktopRole) {
        await _refreshDesktop();
      } else {
        await _refreshMobile();
      }
    } finally {
      try {
        freshResets = await ResetsClient.fetch();
      } catch (_) {}
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshDesktop() async {
    await _server.start();
    serverRunning = _server.isRunning;
    await Pricing.shared.loadRemoteIfNeeded();

    final claudeFuture = ClaudeOAuth.fetch();
    final resetsFuture = ResetsClient.fetch().catchError((_) => <ResetEvent>[]);
    final snap = await compute(_parseInBackground, null) ?? await LocalParser(Pricing.shared).parseAll();

    snap.claudeLimits = await claudeFuture;
    snap.resets = (await resetsFuture).take(60).toList();
    snapshot = snap;
    lastSyncAt = DateTime.now();
    _server.payload = jsonEncode(snap.toJson());
    await _cache(snap);
  }

  Future<void> _refreshMobile() async {
    try {
      final snap = manualAddress.isEmpty
          ? await LanClient.discoverAndFetch()
          : await LanClient.fetchManual(manualAddress);
      snapshot = snap;
      lastSyncAt = DateTime.now();
      await _cache(snap);
    } catch (_) {
      syncError = snapshot == null
          ? '未找到桌面端：请确认 Mac/Windows 上的「AI 用量」在运行，且两台设备连同一 Wi-Fi'
          : '本次同步失败，正在显示上次缓存的数据';
    }
  }

  Future<void> _cache(UsageSnapshot snap) async {
    try {
      await _prefs?.setString('snapshotCache', jsonEncode(snap.toJson()));
    } catch (_) {}
  }
}

/// compute() 需要顶层函数；解析放到隔离区避免卡 UI。
Future<UsageSnapshot?> _parseInBackground(void _) async {
  try {
    await Pricing.shared.loadRemoteIfNeeded();
    return await LocalParser(Pricing.shared).parseAll();
  } catch (_) {
    return null;
  }
}
