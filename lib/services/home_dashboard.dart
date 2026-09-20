import '../models/folder_stats.dart' show achievementFraction;
import '../models/home_index.dart';
import '../models/rom_result.dart';
import 'game_lookup.dart' show romFromEntry;
import 'ignored_candidates.dart';
import 'library.dart';
import 'member_key.dart';
import 'ra_service.dart' show RaAward;
import 'recommender.dart';
import 'play_view.dart';

/// Headline counts for the dashboard's stat strip.
class DashboardStats {
  final int totalGames; // every ROM across every system (matched or not)
  final int systems;
  final int mastered; // sets fully earned on casual
  final int achievementsEarned;
  final int totalSizeBytes;

  const DashboardStats({
    required this.totalGames,
    required this.systems,
    required this.mastered,
    required this.achievementsEarned,
    required this.totalSizeBytes,
  });

  static const empty = DashboardStats(
    totalGames: 0,
    systems: 0,
    mastered: 0,
    achievementsEarned: 0,
    totalSizeBytes: 0,
  );
}

/// The Home dashboard, assembled from the matched games already loaded by the
/// screen. A transient view-model over mutable [RomResult]s, not persisted.
class HomeDashboard {
  /// The single featured game (closest to a mastery badge, else a fallback).
  final RomResult? spotlight;

  /// The second featured game: closest to RA's "beaten" award (a started game
  /// not yet beaten), or null when every started game is already beaten.
  final RomResult? beatSpotlight;

  /// In-progress games, most recently played first.
  final List<RomResult> continuePlaying;

  /// In-progress games, highest completion first (fastest masteries).
  final List<RomResult> closestToMastery;

  /// Never-played games with the biggest communities.
  final List<RomResult> popularUnplayed;

  final DashboardStats stats;

  const HomeDashboard({
    required this.spotlight,
    required this.beatSpotlight,
    required this.continuePlaying,
    required this.closestToMastery,
    required this.popularUnplayed,
    required this.stats,
  });

  bool get hasContent =>
      spotlight != null ||
      continuePlaying.isNotEmpty ||
      closestToMastery.isNotEmpty ||
      popularUnplayed.isNotEmpty;
}

int _total(RomResult r) => r.achievementCount ?? 0;
int _earned(RomResult r) => r.earnedAchievements ?? 0;
double _ratio(RomResult r) => achievementFraction(_earned(r), _total(r));
bool _mastered(RomResult r) => _total(r) > 0 && _earned(r) >= _total(r);

/// True once RA has recorded any award tier (beaten or better). A missing award
/// (null / none) reads as not-yet-beaten, which is corrected on the next sweep.
bool _beaten(RomResult r) {
  final a = r.highestAward;
  return a != null && a != RaAward.none;
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

/// The library's matched games (each carrying its system's display name) plus the
/// system summaries, walked once. Shared by every read-only surface: the home
/// dashboard screen and all three big-picture content tabs derive from this.
Future<(List<RomResult>, List<SystemSummary>)> loadMatchedGames(
    {Library? library}) async {
  final lib = library ?? Library.instance;
  final summaries = await lib.summaries();
  final games = <RomResult>[];
  for (final s in summaries) {
    final data = await lib.load(s.systemPath);
    for (final e in data.games) {
      if (e.matched && e.gameInfo != null) {
        games.add(romFromEntry(e, consoleName: s.name));
      }
    }
  }
  return (games, summaries);
}

/// Walks the library and assembles its [HomeDashboard].
Future<HomeDashboard> loadHomeDashboard({Library? library, int limit = 12}) async {
  final (games, summaries) = await loadMatchedGames(library: library);
  final ignored = await IgnoredCandidates.instance.load();
  return buildHomeDashboard(games,
      systems: summaries, limit: limit, ignoredKeys: ignored);
}

/// The first game in [games] not in [ignoredKeys], or null when every
/// candidate has been dismissed. Used to pick the mastery/beat spotlight so a
/// dismissed game falls through to the next candidate instead of hiding the
/// hero outright.
RomResult? _firstEligible(Iterable<RomResult> games, Set<String> ignoredKeys) {
  for (final r in games) {
    if (!ignoredKeys.contains(memberKeyFor(gameId: r.gameId, filePath: r.filePath))) {
      return r;
    }
  }
  return null;
}

/// Builds the dashboard from the supported games in the library. Pure, no I/O.
/// The ranked buckets reuse [Recommender] so Home and Play Next agree; the
/// spotlight and "continue playing" ordering are Home-specific. [systems] feeds
/// the stat strip; pass the library summaries.
HomeDashboard buildHomeDashboard(
  List<RomResult> games, {
  List<SystemSummary> systems = const [],
  int limit = 12,
  Set<String> ignoredKeys = const {},
}) {
  // One entry per game across every bucket and the stat strip, by the same rule
  // the recommender uses.
  final withSet = dedupeByGame(
    games.where((r) => _total(r) > 0),
    key: (r) => r.gameId ?? r.filePath,
    earned: _earned,
  );
  final byPath = {for (final r in withSet) r.filePath: r};

  final recs = Recommender.build([
    for (final r in withSet)
      RecGame(
        title: listingTitle(r.gameTitle, r.fileName),
        systemName: r.consoleName ?? '',
        filePath: r.filePath,
        gameId: r.gameId,
        total: _total(r),
        earned: _earned(r),
        hardcoreEarned: r.earnedHardcore ?? 0,
        players: r.numPlayersCasual ?? 0,
      ),
  ], limit: limit);
  List<RomResult> lookup(List<RecGame> l) =>
      [for (final g in l) ?byPath[g.filePath]];

  final closest = lookup(recs.closestToMastery);
  final popular = lookup(recs.popularUnplayed);

  final continuePlaying = withSet
      .where((r) => _earned(r) > 0 && !_mastered(r))
      .toList()
    ..sort((a, b) => (b.lastPlayed ?? _epoch).compareTo(a.lastPlayed ?? _epoch));

  // Prefer a mastery target; fall back to whatever the library can offer so a
  // library with only unplayed games still gets a hero. Skips games dismissed
  // via [ignoredKeys], falling through to the next candidate in each bucket.
  final spotlight = _firstEligible(closest, ignoredKeys) ??
      _firstEligible(continuePlaying, ignoredKeys) ??
      _firstEligible(popular, ignoredKeys);

  // Started but not yet beaten, most-complete first. ponytail: completion % is
  // a proxy for closeness-to-beaten; the true signal is remaining progression /
  // win-condition achievements, which we don't fetch in the bulk sweep. Upgrade
  // to rank on those once achievement Type is swept. Excludes the mastery
  // spotlight so the two heroes never feature the same game.
  final beatCandidates = withSet
      .where((r) =>
          _earned(r) > 0 &&
          !_mastered(r) &&
          !_beaten(r) &&
          r.filePath != spotlight?.filePath)
      .toList()
    ..sort((a, b) => _ratio(b).compareTo(_ratio(a)));
  final beatSpotlight = _firstEligible(beatCandidates, ignoredKeys);

  return HomeDashboard(
    spotlight: spotlight,
    beatSpotlight: beatSpotlight,
    continuePlaying: continuePlaying.take(limit).toList(),
    closestToMastery: closest,
    popularUnplayed: popular,
    stats: DashboardStats(
      totalGames: systems.fold(0, (s, e) => s + e.totalGames),
      systems: systems.length,
      mastered: withSet.where(_mastered).length,
      achievementsEarned: withSet.fold(0, (s, r) => s + _earned(r)),
      totalSizeBytes: systems.fold(0, (s, e) => s + e.totalSizeBytes),
    ),
  );
}
