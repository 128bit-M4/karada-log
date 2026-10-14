import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'cycle_page.dart';
import 'notifier.dart';
import 'record_page.dart';
import 'settings_page.dart';
import 'steps_page.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  await Store.instance.init();
  try {
    await Notifier.init();
    await Store.instance.reschedule();
  } catch (_) {}
  runApp(const KaradaApp());
}

class KaradaApp extends StatelessWidget {
  const KaradaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'からだ記録',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE5667F)),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0; // 最優先の「歩数」を最初に表示

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Store.instance.startSteps();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      Store.instance.flushSteps();
    }
  }

  @override
  Widget build(BuildContext context) {
    const pages = [StepsPage(), CyclePage(), RecordPage(), SettingsPage()];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_walk), label: '歩数'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '周期'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '記録'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}
