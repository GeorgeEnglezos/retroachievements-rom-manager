import 'package:flutter/material.dart';

import '../models/game_entry.dart';
import '../models/rom_group.dart';
import '../models/rom_result.dart';
import '../models/rom_row.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/playlist_store.dart';
import '../services/recommender.dart';
import '../widgets/rom_list_view.dart';
import '../widgets/row_display.dart';

/// "What should I play next?": ranked buckets over all systems. Read-only.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final PlaylistStore _store = PlaylistStore();
  Recommendations? _recs;
  final Map<String, RomResult> _byPath = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summaries = await Library.instance.summaries();
    final store = Library.instance;
    final games = <RecGame>[];
    _byPath.clear();
    for (final s in summaries) {
      final data = await store.load(s.systemPath);
      for (final e in data.games) {
        if (!e.matched || e.gameInfo == null) continue;
        _byPath[e.filePath] = _toRom(e, s.name);
        games.add(RecGame(
          title: e.gameInfo!.title,
          systemName: s.name,
          filePath: e.filePath,
          gameId: e.gameId,
          total: e.gameInfo!.achievementCount,
          earned: e.progress?.earnedAchievements ?? 0,
          hardcoreEarned: e.progress?.earnedHardcore ?? 0,
          players: e.gameInfo!.numPlayersCasual,
        ));
      }
    }
    if (!mounted) return;
    setState(() => _recs = Recommender.build(games));
  }

  // Rebuilds the persisted entry into the RomResult the shared tile renders. The
  // gameInfo is present (callers filter on matched && gameInfo != null).
  RomResult _toRom(GameEntry e, String consoleName) =>
      romFromEntry(e, consoleName: consoleName)
        ..earnedAchievements = e.progress?.earnedAchievements ?? 0;

  RomGroup? _group(String label, List<RecGame> games) {
    final rows = games
        .map((g) => _byPath[g.filePath])
        .whereType<RomResult>()
        .map(RomRow.fromRom)
        .toList();
    if (rows.isEmpty) return null;
    return RomGroup(label: '$label · ${rows.length}', rows: rows);
  }

  @override
  Widget build(BuildContext context) {
    final r = _recs;
    if (r == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (r.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No supported games with achievement data yet. '
              'Fetch some systems first.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final groups = [
      _group('Closest to mastery', r.closestToMastery),
      _group('Popular & unplayed', r.popularUnplayed),
      _group('Quick hardcore re-clears', r.hardcoreReclears),
    ].whereType<RomGroup>().toList();

    return Scaffold(
      body: RomListView(
        groups: groups,
        display: RowDisplay.roms,
        store: _store,
      ),
    );
  }
}
