import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/android_emulators.dart';
import '../services/app_mode.dart';
import '../services/library.dart';
import '../services/log_service.dart';
import '../services/play_view.dart';
import '../screens/cull_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/home_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/recommendations_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/storage_screen.dart';
import '../services/update_check.dart';
import '../theme/ui_tokens.dart';
import 'update_banner.dart';

/// The shell's nav destinations (label, icon), indexed by the ints in
/// [kGamingNav] / [kCleaningNav]. Public so a route pushed over the shell (a
/// FolderView's landscape rail) can render the same set.
const List<(String, IconData)> kShellDests = <(String, IconData)>[
  ('HOME', Icons.home_rounded),
  ('LIBRARY', Icons.grid_view),
  ('PLAY NEXT', Icons.recommend_outlined),
  ('CULL', Icons.style_outlined),
  ('STORAGE', Icons.pie_chart),
  ('LOGS', Icons.receipt_long),
  ('SETTINGS', Icons.settings),
];

// Which _dests the two modes offer. Gaming keeps browsing and playing; culling,
// storage and logs are maintenance.
const List<int> kCleaningNav = [0, 1, 2, 3, 4, 5, 6];
const List<int> kGamingNav = [0, 1, 2, 6];

/// The dest indices the shell shows for [mode].
List<int> shellNavFor(AppMode mode) =>
    mode == AppMode.gaming ? kGamingNav : kCleaningNav;

/// Registered by the live [AppShell]. A route pushed over the shell (e.g. a
/// FolderView's landscape rail) calls this to pop back to the shell and switch
/// to [destIndex]. Null when no shell is mounted (isolated widget tests).
void Function(int destIndex)? shellNavigate;

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
    shellNavigate = _navigateFromPushed;
    _loadVersion();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      _drainPendingShortcut(); // cold start via a home-screen shortcut
    }
  }

  // Called by a route pushed over the shell (a FolderView's nav rail). Pop back
  // to the shell, then switch tabs — the pushed route is gone, the tab shows.
  void _navigateFromPushed(int destIndex) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    _select(destIndex);
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
    if (shellNavigate == _navigateFromPushed) shellNavigate = null;
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

  // HOME is the cover-art dashboard; the folder/system grid and scanning moved
  // to its own LIBRARY tab. Both stay mounted in the IndexedStack, so the
  // library screen's boot refresh and setup-wizard first-scan handoff still run.
  // Deliberately not const: a const child is canonicalized to the same
  // instance every build, and Element.updateChild skips a subtree whose widget
  // is identical. That silently swallowed every mode/play-view change, since
  // the IndexedStack keeps these mounted rather than rebuilding them on nav.
  List<Widget> get _bodies => [
        DashboardScreen(onOpenLibrary: () => _select(1)),
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
  // Both listenables rebuild the whole shell: the screens below live in an
  // IndexedStack and are never popped, so a Settings change would otherwise not
  // reach the listing they're about.
  Widget build(BuildContext context) => ValueListenableBuilder<AppMode>(
        valueListenable: appModeListenable,
        builder: (context, mode, _) => ValueListenableBuilder<PlayView>(
          valueListenable: playViewListenable,
          builder: (context, _, _) => _buildShell(context, mode),
        ),
      );

  Widget _buildShell(BuildContext context, AppMode mode) {
    final ui = context.ui;
    final nav = shellNavFor(mode);
    // Switching to gaming while sitting on a maintenance tab would otherwise
    // strand _index on a destination the nav no longer draws. Derive the shown
    // one instead of writing state during build; _index survives, so flipping
    // back lands you where you were.
    final active = nav.contains(_index) ? _index : nav.first;
    final dests = [for (final i in nav) kShellDests[i]];
    final pos = nav.indexOf(active);
    // Deliberately MediaQuery, not a LayoutBuilder: the shell's body is the
    // whole window, so the two widths agree, but a LayoutBuilder would build
    // every screen inside its layout callback. Anything that then landed a
    // setState mid-layout (a playlist refresh on the way back from a pushed
    // route) rebuilt in the wrong build scope and tore a subtree down while its
    // controllers were still attached.
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= kBreakWide;
    // A phone held sideways: short-and-wide, on Android (desktop/tablet keep
    // their layouts). Landscape gets its own shell — nav stood up on a left
    // rail, and the portrait layout's top title strip dropped entirely.
    final landscapePhone = context.isLandscapePhone;
    final stack = IndexedStack(index: active, children: _bodies);
    final update = _update;
    final banner = update == null
        ? null
        : UpdateBanner(update: update, onDismiss: _dismissUpdate);
    if (landscapePhone) {
      return Scaffold(
        backgroundColor: ui.background,
        body: SafeArea(
          child: Row(
            children: [
              _Rail(
                key: const Key('landscape_rail'),
                dests: dests,
                index: pos,
                onSelect: (p) => _select(nav[p]),
              ),
              Expanded(
                child: Column(
                  children: [
                    ?banner,
                    Expanded(child: stack),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: ui.background,
      body: wide
          ? Row(
              children: [
                _Sidebar(
                    dests: dests,
                    index: pos,
                    onSelect: (p) => _select(nav[p]),
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
                _TopTitle(key: const Key('top_title'), label: dests[pos].$1),
                ?banner,
                Expanded(child: stack),
                _BottomNav(
                    dests: dests,
                    index: pos,
                    onSelect: (p) => _select(nav[p])),
              ],
            ),
    );
  }
}

/// Shared surface for the shell's four nav bars (sidebar, top title, bottom
/// nav, landscape rail): a border on one edge, no background fill, so the bar
/// blends with the body behind it instead of sitting on a solid panel.
class _NavSurface extends StatelessWidget {
  final Border border;
  final double? width;
  final Widget child;
  const _NavSurface({required this.border, this.width, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(border: border),
        child: child,
      );
}

/// Mobile-only bar naming the active tab (the bottom nav shows icons only).
class _TopTitle extends StatelessWidget {
  final String label;
  const _TopTitle({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _NavSurface(
      width: double.infinity,
      border: Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
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
    return _NavSurface(
      width: 180,
      border: Border(right: BorderSide(color: ui.border, width: ui.borderWidth)),
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
    final fg = selected ? ui.navSelectedFg : ui.muted;
    // Rounded pill inset from the rail edge, as the reference sidebar does.
    // The visible Text names the destination; only the active state needs
    // carrying, since it is otherwise conveyed by the fill alone.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: ui.roundMd,
          child: Container(
            decoration: BoxDecoration(
              color: selected ? ui.navSelectedBg : Colors.transparent,
              borderRadius: ui.roundMd,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Text(label, style: ui.labelCaps.copyWith(color: fg)),
              ],
            ),
          ),
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
    return _NavSurface(
      border: Border(top: BorderSide(color: ui.border, width: ui.borderWidth)),
      // Keep the bar's border but inset the tappable icons above the system
      // navigation bar (gesture pill / 3-button nav) on Android/iOS.
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < dests.length; i++)
              Expanded(
                // The bar is icon-only, so the destination name exists nowhere
                // a screen reader can reach it. Carry it in the semantics.
                child: Semantics(
                  container: true,
                  button: true,
                  selected: i == index,
                  label: dests[i].$1,
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: ui.roundMd,
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: i == index ? ui.navSelectedBg : Colors.transparent,
                        borderRadius: ui.roundMd,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        dests[i].$2,
                        color: i == index ? ui.navSelectedFg : ui.muted,
                        size: 22,
                      ),
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

/// The landscape-phone navigation rail: a slim icon-only column down the left,
/// replacing both the portrait bottom bar and its top title strip. Icons scroll
/// if a tall nav (cleaning's seven) outgrows a short landscape height.
class _Rail extends StatelessWidget {
  final List<(String, IconData)> dests;
  final int index;
  final ValueChanged<int> onSelect;
  const _Rail(
      {super.key,
      required this.dests,
      required this.index,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return _NavSurface(
      width: 64,
      border: Border(right: BorderSide(color: ui.border, width: ui.borderWidth)),
      // Scrolls if a tall nav (cleaning's seven) outgrows a short landscape.
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            for (int i = 0; i < dests.length; i++)
              ShellRailTile(
                label: dests[i].$1,
                icon: dests[i].$2,
                selected: i == index,
                onTap: () => onSelect(i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A single icon-only tile in a landscape nav rail. Public so a pushed route
/// (a FolderView's rail) can render nav tiles that match the shell's.
class ShellRailTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ShellRailTile(
      {super.key,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final fg = selected ? ui.navSelectedFg : ui.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      // Icon-only, so the name lives in a tooltip (mouse/long-press) and in the
      // semantics (screen readers), the way the bottom bar carries it.
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: ui.roundMd,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? ui.navSelectedBg : Colors.transparent,
                borderRadius: ui.roundMd,
              ),
              child: Icon(icon, size: 22, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

