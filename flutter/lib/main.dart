import 'package:flutter/material.dart';

import 'store.dart';
import 'ui/pages.dart';

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
    const seed = Color(0xFF2E7DE1);
    return MaterialApp(
      title: 'AI 用量',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed), useMaterial3: true),
      darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark), useMaterial3: true),
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
            // 桌面宽窗口：侧边导航
            return Scaffold(
              appBar: AppBar(title: const Text('AI 用量'), actions: [_refreshAction()]),
              body: Row(children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.grid_view), label: Text('总览')),
                    NavigationRailDestination(icon: Icon(Icons.restart_alt), label: Text('重置动态')),
                    NavigationRailDestination(icon: Icon(Icons.sync), label: Text('同步')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ]),
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('AI 用量'), actions: [_refreshAction()]),
            body: body,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.grid_view), label: '总览'),
                NavigationDestination(icon: Icon(Icons.restart_alt), label: '重置动态'),
                NavigationDestination(icon: Icon(Icons.sync), label: '同步'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _refreshAction() {
    return IconButton(
      onPressed: store.isRefreshing ? null : store.refresh,
      icon: store.isRefreshing
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh),
      tooltip: '立即刷新',
    );
  }
}
