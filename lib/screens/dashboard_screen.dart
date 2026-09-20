import 'dart:async';

import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../services/home_dashboard.dart';
import '../services/ignored_candidates.dart';
import '../services/library.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../services/settings_bus.dart';
import '../theme/ui_tokens.dart';
import '../widgets/bigpicture/couch_home.dart';
import '../widgets/game_detail_dialog.dart';

/// The Home tab for Cleaning and Play modes. It loads the dashboard and opens a
/// game's detail dialog on tap, then hands the layout to [CouchHome], the single
/// Home component shared by every mode (Big Picture renders the same widget from
/// its own shell). Browsing by system and scanning live on the Library tab.
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

  @override
  void initState() {
    super.initState();
    _lib.addListener(_scheduleLoad);
    settingsChanged.addListener(_scheduleLoad);
    // Warm the scraped store so a game's detail dialog can fall back to imported
    // artwork, matching the folder/storage screens.
    ScrapedStore.instance.load();
    _load();
  }

  @override
  void dispose() {
    _lib.removeListener(_scheduleLoad);
    settingsChanged.removeListener(_scheduleLoad);
    _debounce?.cancel();
    super.dispose();
  }

  // A scan saves once per system in a burst; coalesce like the other tabs.
  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    // A wide Home row shows well over a dozen covers; load enough to fill it.
    final dash = await loadHomeDashboard(library: _lib, limit: 30);
    if (!mounted) return;
    setState(() {
      _dash = dash;
      _loading = false;
    });
    // Home paints first; the two featured banners have no art until their
    // detail is fetched, and persisting it notifies the library, which reloads
    // us with the art in place.
    unawaited(fetchSpotlightArt(dash, library: _lib));
  }

  Future<void> _ignore(RomResult rom) async {
    final key = memberKeyFor(gameId: rom.gameId, filePath: rom.filePath);
    await IgnoredCandidates.instance.ignore(key);
    if (mounted) {
      final title = gameDisplayName(rom.gameTitle, rom.fileName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Won\'t suggest "$title" here again'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await IgnoredCandidates.instance.unignore(key);
            _load();
          },
        ),
      ));
    }
    await _load();
  }

  void _open(RomResult rom) {
    openRomOnTap(context, rom,
        store: _store, onDeleted: _load, onPlaylistChanged: _load);
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
    return CouchHome(dashboard: dash, onOpen: _open, onIgnore: _ignore);
  }
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
