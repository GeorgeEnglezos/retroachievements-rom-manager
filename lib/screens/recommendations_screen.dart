import 'package:flutter/material.dart';

import '../models/game_entry.dart';
import '../models/rom_result.dart';
import '../services/couch_rows.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
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
    _load();
  }

  Future<void> _load() async {
    final summaries = await Library.instance.summaries();
    final store = Library.instance;
    final games = <RomResult>[];
    for (final s in summaries) {
      final data = await store.load(s.systemPath);
      for (final e in data.games) {
        if (!e.matched || e.gameInfo == null) continue;
        games.add(_toRom(e, s.name));
      }
    }
    if (!mounted) return;
    setState(() => _games = games);
  }

  // Rebuilds the persisted entry into the RomResult the shared tile renders. The
  // gameInfo is present (callers filter on matched && gameInfo != null).
  RomResult _toRom(GameEntry e, String consoleName) =>
      romFromEntry(e, consoleName: consoleName)
        ..earnedAchievements = e.progress?.earnedAchievements ?? 0;

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
