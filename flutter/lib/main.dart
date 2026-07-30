import 'package:flutter/material.dart';

import 'store.dart';
import 'ui/pages.dart';
import 'ui/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AIUsageApp());
}

class AIUsageApp extends StatefulWidget {
  const AIUsageApp({super.key});

  @override
  State<AIUsageApp> createState() => _AIUsageAppState();
}

class _AIUsageAppState extends State<AIUsageApp> {
  final store = AppStore();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    store.start();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = ColorScheme.dark(
      primary: Palette.signal,
      onPrimary: Palette.canvas,
      secondary: Palette.claudeColor,
      onSecondary: Palette.canvas,
      surface: Palette.surface,
      onSurface: Palette.ink,
      error: Palette.danger,
      outline: Palette.line,
      outlineVariant: Palette.line,
    );
    return MaterialApp(
      title: 'AI 用量',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: Palette.canvas,
        fontFamily: 'sans-serif',
        useMaterial3: true,
        splashFactory: InkSparkle.splashFactory,
        dividerColor: Palette.line,
        appBarTheme: const AppBarTheme(
          backgroundColor: Palette.canvas,
          foregroundColor: Palette.ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Palette.surface,
          indicatorColor: Palette.signal.withValues(alpha: 0.13),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Palette.muted,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Palette.surfaceRaised,
          hintStyle: const TextStyle(
            color: Palette.muted,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Palette.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Palette.signal),
          ),
        ),
      ),
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final pages = [
            DashboardPage(store: store),
            ResetsPage(store: store),
            SyncPage(store: store),
          ];
          final wide = MediaQuery.of(context).size.width >= 700;
          final body = pages[_tab];
          if (wide) {
            return _desktopShell(body);
          }
          return _mobileShell(body);
        },
      ),
    );
  }

  Widget _desktopShell(Widget body) {
    const destinations = [
      (Icons.terminal_rounded, '用量'),
      (Icons.restart_alt_rounded, '重置动态'),
      (Icons.sync_rounded, '同步'),
    ];
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 190,
            decoration: const BoxDecoration(
              color: Palette.canvas,
              border: Border(right: BorderSide(color: Palette.line)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _brandHeader(),
                  const SizedBox(height: 14),
                  for (final (index, item) in destinations.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: _sideNavItem(index, item.$1, item.$2),
                    ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: StatusPill(
                      text: store.serverRunning ? 'SYNC ONLINE' : 'LOCAL MODE',
                      isLive: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Palette.canvas,
                    border: Border(bottom: BorderSide(color: Palette.line)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        destinations[_tab].$2.toUpperCase(),
                        style: const TextStyle(
                          color: Palette.muted,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const Spacer(),
                      _refreshAction(),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileShell(Widget body) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '~/',
              style: TextStyle(color: Palette.signal, fontFamily: 'monospace'),
            ),
            const Text(
              'AIUsage',
              style: TextStyle(
                color: Palette.ink,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [_refreshAction()],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal_rounded),
            label: '用量',
          ),
          NavigationDestination(
            icon: Icon(Icons.restart_alt_rounded),
            label: '重置',
          ),
          NavigationDestination(icon: Icon(Icons.sync_rounded), label: '同步'),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '~/',
                style: TextStyle(
                  color: Palette.signal,
                  fontFamily: 'monospace',
                  fontSize: 17,
                ),
              ),
              Text(
                'AIUsage',
                style: TextStyle(
                  color: Palette.ink,
                  fontFamily: 'monospace',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            'LOCAL USAGE METER',
            style: TextStyle(
              color: Palette.muted,
              fontFamily: 'monospace',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideNavItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Palette.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Palette.line : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              selected ? '>' : ' ',
              style: const TextStyle(
                color: Palette.signal,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 17, color: selected ? Palette.ink : Palette.muted),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: selected ? Palette.ink : Palette.muted,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _refreshAction() {
    return IconButton(
      onPressed: store.isRefreshing ? null : store.refresh,
      icon: store.isRefreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, color: Palette.muted),
      tooltip: '立即刷新',
    );
  }
}
