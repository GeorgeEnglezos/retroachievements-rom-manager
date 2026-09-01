import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rom_result.dart';
import '../services/game_lookup.dart';
import '../services/home_dashboard.dart';
import '../services/library.dart';
import '../services/playlist_store.dart';
import '../services/pref_keys.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/dashboard_stats.dart';
import '../widgets/game_detail_dialog.dart';
import '../widgets/spotlight_hero.dart';
import '../widgets/ui/ui_segmented.dart';

/// The Home tab: a cover-art dashboard over the whole scanned library —
/// spotlight, at-a-glance stats, and "jump back in" rails. Browsing by system
/// and running scans lives on the Library tab; this surface is read-first.
class DashboardScreen extends StatefulWidget {
  /// Sends the user to the Library tab (owned by the shell) from the empty
  /// state. Null falls back to a plain message.
  final VoidCallback? onOpenLibrary;

  /// Injectable for tests; defaults to the shared instance.
  final Library? library;

  const DashboardScreen({super.key, this.onOpenLibrary, this.library});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Library _lib = widget.library ?? Library.instance;
  final PlaylistStore _store = PlaylistStore();
  HomeDashboard? _dash;
  bool _loading = true;
  Timer? _debounce;
  DashboardLayout _layout = DashboardLayout.grid;

  @override
  void initState() {
    super.initState();
    _lib.addListener(_scheduleLoad);
    // Warm the scraped store so a game's detail dialog can fall back to imported
    // artwork, matching the folder/storage screens.
    ScrapedStore.instance.load();
    _loadLayoutPref();
    _load();
  }

  @override
  void dispose() {
    _lib.removeListener(_scheduleLoad);
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadLayoutPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = DashboardLayout.values
        .asNameMap()[prefs.getString(PrefKeys.dashboardLayout)];
    if (v != null && mounted) setState(() => _layout = v);
  }

  Future<void> _setLayout(DashboardLayout v) async {
    setState(() => _layout = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.dashboardLayout, v.name);
  }

  // A scan saves once per system in a burst; coalesce like the other tabs.
  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final summaries = await _lib.summaries();
    final games = <RomResult>[];
    for (final s in summaries) {
      final data = await _lib.load(s.systemPath);
      for (final e in data.games) {
        if (e.matched && e.gameInfo != null) {
          games.add(romFromEntry(e, consoleName: s.name));
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _dash = buildHomeDashboard(games, systems: summaries);
      _loading = false;
    });
  }

  void _open(RomResult rom) {
    showDialog<void>(
      context: context,
      builder: (_) => GameDetailDialog(
        rom: rom,
        store: _store,
        onDeleted: _load,
        onPlaylistChanged: _load,
        scraped: ScrapedStore.instance.get(rom.filePath),
      ),
    );
  }

  /// One bucket, rendered the way this width wants it. Wide windows fill one
  /// row with as many covers as fit and stop there; phones use the picked
  /// vertical layout.
  Widget _section(
    String title,
    List<RomResult> games, {
    required bool narrow,
  }) {
    if (!narrow) {
      return DashboardCoverSection(
        title: title,
        games: games,
        onOpen: _open,
      );
    }
    return switch (_layout) {
      DashboardLayout.list => DashboardListSection(
          title: title,
          games: games,
          onOpen: _open,
        ),
      DashboardLayout.grid => DashboardCoverSection(
          title: title,
          games: games,
          onOpen: _open,
          columns: 3,
          rows: 2,
        ),
    };
  }

  /// The featured banners: the mastery hero, plus a "closest to beat" hero when
  /// one exists. Side by side once there's room ([wide]); stacked below that.
  List<Widget> _heroes(HomeDashboard dash,
      {required bool narrow, required bool wide}) {
    final mastery = dash.spotlight;
    if (mastery == null) return const [];
    final masteryHero = SpotlightHero(
        rom: mastery, compact: narrow, onOpen: () => _open(mastery));

    final beat = dash.beatSpotlight;
    if (beat == null) return [masteryHero];
    final beatHero = SpotlightHero(
      rom: beat,
      compact: narrow,
      eyebrow: 'CLOSEST TO BEAT',
      onOpen: () => _open(beat),
    );

    if (wide) {
      return [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: masteryHero),
              const SizedBox(width: 16),
              Expanded(child: beatHero),
            ],
          ),
        ),
      ];
    }
    return [masteryHero, const SizedBox(height: 16), beatHero];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final dash = _dash;
    if (dash == null || !dash.hasContent) {
      return _EmptyDashboard(onOpenLibrary: widget.onOpenLibrary);
    }
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 600;

    return ListView(
      padding: narrow
          ? const EdgeInsets.fromLTRB(16, 16, 16, 32)
          : const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        ..._heroes(dash, narrow: narrow, wide: width >= 900),
        const SizedBox(height: 8),
        DashboardStatStrip(stats: dash.stats, narrow: narrow),
        if (narrow) _LayoutPicker(value: _layout, onChanged: _setLayout),
        _section('Jump back in', dash.continuePlaying, narrow: narrow),
        _section('Closest to mastery', dash.closestToMastery, narrow: narrow),
        _section('Popular & unplayed', dash.popularUnplayed, narrow: narrow),
      ],
    );
  }
}

/// Flips the phone dashboard between its section layouts. The choice persists
/// (PrefKeys.dashboardLayout); wide windows never show it.
class _LayoutPicker extends StatelessWidget {
  final DashboardLayout value;
  final ValueChanged<DashboardLayout> onChanged;

  const _LayoutPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        // Align keeps the control at its content width; a ListView child is
        // otherwise stretched to the full row.
        child: Align(
          alignment: Alignment.centerLeft,
          child: UiSegmented<DashboardLayout>(
            value: value,
            onChanged: onChanged,
            segments: const [
              (value: DashboardLayout.list, label: 'List', icon: null),
              (value: DashboardLayout.grid, label: 'Grid', icon: null),
            ],
          ),
        ),
      );
}

class _EmptyDashboard extends StatelessWidget {
  final VoidCallback? onOpenLibrary;
  const _EmptyDashboard({this.onOpenLibrary});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 56, color: ui.muted),
            const SizedBox(height: 16),
            Text(
              'Your dashboard fills up as you play',
              textAlign: TextAlign.center,
              style: ui.display.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick your ROM folder and run a scan on the Library tab. Games you '
              'have progress on show up here, closest to mastery first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ui.muted),
            ),
            if (onOpenLibrary != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onOpenLibrary,
                icon: const Icon(Icons.grid_view, size: 18),
                label: const Text('Go to Library'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
