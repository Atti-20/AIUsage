import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'net.dart';
import 'parsers.dart';
import 'pricing.dart';

/// 应用数据中枢。
/// 桌面角色（Windows/macOS/Linux）：本地解析 + 官方限额 + 重置预测 + 局域网服务。
/// 移动角色（Android）：局域网发现/手动地址拉取 + 本地缓存 + 重置预测。
class AppStore extends ChangeNotifier {
  static const _widgetChannel = MethodChannel('aiusage/widget');
  static bool get isDesktopRole =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  UsageSnapshot? snapshot;
  bool isRefreshing = false;
  String? syncError;
  DateTime? lastSyncAt;
  String manualAddress = '';
  bool serverRunning = false;
  bool showClaudeUsage = true;
  bool showCodexUsage = true;
  bool showOfficialLimitWarnings = true;
  bool showCodexResetPrediction = true;

  final _server = SnapshotServer();
  Timer? _timer;
  SharedPreferences? _prefs;

  Future<void> start() async {
    _prefs = await SharedPreferences.getInstance();
    manualAddress = _prefs?.getString('manualAddress') ?? '';
    showClaudeUsage = _prefs?.getBool('display.showClaudeUsage') ?? true;
    showCodexUsage = _prefs?.getBool('display.showCodexUsage') ?? true;
    showOfficialLimitWarnings =
        _prefs?.getBool('display.showOfficialLimitWarnings') ?? true;
    showCodexResetPrediction =
        _prefs?.getBool('display.showCodexResetPrediction') ?? true;
    final cached = _prefs?.getString('snapshotCache');
    if (cached != null) {
      try {
        snapshot = UsageSnapshot.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
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

  Future<void> setShowClaudeUsage(bool value) async {
    showClaudeUsage = value;
    notifyListeners();
    await _prefs?.setBool('display.showClaudeUsage', value);
    await _reloadAndroidWidget();
  }

  Future<void> setShowCodexUsage(bool value) async {
    showCodexUsage = value;
    notifyListeners();
    await _prefs?.setBool('display.showCodexUsage', value);
    await _reloadAndroidWidget();
  }

  Future<void> setShowOfficialLimitWarnings(bool value) async {
    showOfficialLimitWarnings = value;
    notifyListeners();
    await _prefs?.setBool('display.showOfficialLimitWarnings', value);
  }

  Future<void> setShowCodexResetPrediction(bool value) async {
    showCodexResetPrediction = value;
    notifyListeners();
    await _prefs?.setBool('display.showCodexResetPrediction', value);
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
        final forecast = await CodexResetForecastClient.fetch();
        snapshot?.codexResetForecast = forecast;
        if (snapshot != null) {
          if (isDesktopRole) {
            _server.payload = jsonEncode(snapshot!.toJson());
          }
          await _cache(snapshot!);
        }
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
    final snap =
        await compute(_parseInBackground, null) ??
        await LocalParser(Pricing.shared).parseAll();

    snap.claudeLimits = await claudeFuture;
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
      await _reloadAndroidWidget();
    } catch (_) {}
  }

  Future<void> _reloadAndroidWidget() async {
    if (!Platform.isAndroid) return;
    try {
      await _widgetChannel.invokeMethod<void>('reload');
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
