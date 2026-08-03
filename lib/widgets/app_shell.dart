import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/android_emulators.dart';
import '../services/library.dart';
import '../services/log_service.dart';
import '../screens/cull_screen.dart';
import '../screens/home_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/recommendations_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/storage_screen.dart';
import '../services/update_check.dart';
import '../theme/ui_tokens.dart';
import 'update_banner.dart';

/// Top-level responsive navigation shell. Holds the destinations in an
/// IndexedStack so each keeps its state across nav switches.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  String _version = '';
  ReleaseUpdate? _update;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      _drainPendingShortcut(); // cold start via a home-screen shortcut
    }
  }

  Future<void> _loadVersion() async {
    final PackageInfo info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {
      // PackageInfo has no platform plugin under tests, leave the label blank.
      // The update check hangs off it deliberately: no version, no request, so
      // the suite stays offline. Mocking PackageInfo in a test would let this
      // reach api.github.com — inject the check instead if that day comes.
      return;
    }
    if (!mounted) return;
    setState(() => _version = 'v${info.version}+${info.buildNumber}');

    final update = await UpdateCheck.check(currentVersion: info.version);
    if (mounted && update != null) setState(() => _update = update);
  }

  void _dismissUpdate() {
    UpdateCheck.skip(_update!.version);
    setState(() => _update = null);
  }

  @override
  void dispose() {
    if (Platform.isAndroid) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tapping a shortcut brings the (singleTop) app to the foreground → resumed.
    if (state == AppLifecycleState.resumed) _drainPendingShortcut();
  }

  // Fires a ROM launch parked by a home-screen shortcut, reusing the normal
  // per-emulator launch path. No-op when nothing is pending.
  Future<void> _drainPendingShortcut() async {
    final pending = await AndroidEmulators.takePendingShortcut();
    if (pending == null) return;
    LogService.info('AppShell/shortcut',
        'Shortcut launch ${pending.romPath} '
        '(pkg=${pending.package}, kind=${pending.kindId}, console=${pending.consoleId})');
    final err = await AndroidEmulators.launchRom(
      package: pending.package,
      kindId: pending.kindId,
      consoleId: pending.consoleId,
      romPath: pending.romPath,
    );
    if (err != null) {
      LogService.error('AppShell/shortcut',
          'Shortcut launch failed for ${pending.romPath} '
          '(pkg=${pending.package}): $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Couldn't launch shortcut: $err")));
      }
    } else {
      LogService.info('AppShell/shortcut', 'Shortcut launch OK: ${pending.romPath}');
    }
  }

  static const _dests = <(String, IconData)>[
    ('HOME', Icons.grid_view),
    ('PLAY NEXT', Icons.recommend_outlined),
    ('CULL', Icons.style_outlined),
    ('STORAGE', Icons.pie_chart),
    ('LOGS', Icons.receipt_long),
    ('SETTINGS', Icons.settings),
  ];

  List<Widget> get _bodies => const [
        HomeScreen(),
        RecommendationsScreen(),
        CullScreen(),
        StorageScreen(),
        LogsScreen(),
        SettingsScreen(),
      ];

  void _select(int i) {
    setState(() => _index = i);
    // A folder can be deleted while the app runs, and every tab counts systems.
    // Re-checking on each switch keeps the tab you land on honest; it notifies
    // only when something actually changed.
    Library.instance.refreshMissingSystems();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    // Deliberately MediaQuery, not a LayoutBuilder: the shell's body is the
    // whole window, so the two widths agree, but a LayoutBuilder would build
    // every screen inside its layout callback. Anything that then landed a
    // setState mid-layout (a playlist refresh on the way back from a pushed
    // route) rebuilt in the wrong build scope and tore a subtree down while its
    // controllers were still attached.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final stack = IndexedStack(index: _index, children: _bodies);
    final update = _update;
    final banner = update == null
        ? null
        : UpdateBanner(update: update, onDismiss: _dismissUpdate);
    return Scaffold(
      backgroundColor: ui.background,
      body: wide
          ? Row(
              children: [
                _Sidebar(
                    dests: _dests,
                    index: _index,
                    onSelect: _select,
                    version: _version),
                // Banner spans the body only, so the sidebar stays unbroken.
                Expanded(
                  child: Column(
                    children: [
                      ?banner,
                      Expanded(child: stack),
                    ],
                  ),
                ),
              ],
            )
          // Mobile: the bottom nav is icon-only, so name the current tab up top.
          : Column(
              children: [
                _TopTitle(label: _dests[_index].$1),
                ?banner,
                Expanded(child: stack),
                _BottomNav(dests: _dests, index: _index, onSelect: _select),
              ],
            ),
    );
  }
}

/// Mobile-only bar naming the active tab (the bottom nav shows icons only).
class _TopTitle extends StatelessWidget {
  final String label;
  const _TopTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ui.surface,
        border:
            Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(label, style: ui.display.copyWith(fontSize: 18)),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<(String, IconData)> dests;
  final int index;
  final ValueChanged<int> onSelect;
  final String version;
  const _Sidebar(
      {required this.dests,
      required this.index,
      required this.onSelect,
      required this.version});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: ui.surface,
        border:
            Border(right: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text('RARM', style: ui.display.copyWith(fontSize: 18)),
          ),
          for (int i = 0; i < dests.length; i++)
            _NavTile(
              label: dests[i].$1,
              icon: dests[i].$2,
              selected: i == index,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          // Version + author pinned bottom-left. Desktop only: mobile has no
          // left rail to hang it on.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (version.isNotEmpty)
                  Text(version,
                      style:
                          ui.labelCaps.copyWith(fontSize: 11, color: ui.muted)),
                Text('by George Englezos',
                    style: ui.labelCaps.copyWith(fontSize: 11, color: ui.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final fg = selected ? ui.navSelectedFg : ui.text;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? ui.navSelectedBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Text(label, style: ui.labelCaps.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final List<(String, IconData)> dests;
  final int index;
  final ValueChanged<int> onSelect;
  const _BottomNav(
      {required this.dests, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: ui.surface,
        border: Border(top: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      // Keep the bar's surface/border but inset the tappable icons above the
      // system navigation bar (gesture pill / 3-button nav) on Android/iOS.
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < dests.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Container(
                    color: i == index ? ui.navSelectedBg : Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Icon(
                      dests[i].$2,
                      color: i == index ? ui.navSelectedFg : ui.text,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

