import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../services/couch_rows.dart';
import '../services/home_dashboard.dart' show loadMatchedGames;
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../services/settings_bus.dart';
import '../widgets/bigpicture/couch_shelves.dart';
import '../widgets/game_detail_dialog.dart';

/// "What should I play next?": a grid of consoles (plus "All Consoles"), each
/// listing its top games, most-played first. Tapping a cover opens its detail
/// dialog.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final PlaylistStore _store = PlaylistStore();
  List<RomResult>? _games;

  @override
  void initState() {
    super.initState();
    ScrapedStore.instance.load();
    settingsChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final (games, _) = await loadMatchedGames();
    if (!mounted) return;
    setState(() => _games = games);
  }

  void _open(RomResult rom) {
    openRomOnTap(context, rom,
        store: _store, onDeleted: _load, onPlaylistChanged: _load);
  }

  @override
  Widget build(BuildContext context) {
    final games = _games;
    if (games == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final rows = playNextRows(games);
    return Scaffold(
      body: ConsoleBrowser(
        rows: rows.consoles,
        overall: rows.overall,
        onOpen: _open,
        emptyMessage: 'No supported games with achievement data yet. '
            'Fetch some systems first.',
      ),
    );
  }
}
