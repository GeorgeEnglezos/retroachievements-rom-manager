import '../models/folder_stats.dart' show achievementFraction;

/// Collapses copies of the same game (same RA gameId in two ROM folders) down
/// to the most-progressed one, so a game is counted and recommended once.
/// [key] falls back to the file path when a matched game has no id, so
/// genuinely distinct games never merge. Shared with the home dashboard, which
/// deduplicates its own buckets by the same rule.
List<T> dedupeByGame<T>(Iterable<T> items,
    {required Object Function(T) key, required int Function(T) earned}) {
  final byGame = <Object, T>{};
  for (final item in items) {
    final prev = byGame[key(item)];
    if (prev == null || earned(item) > earned(prev)) byGame[key(item)] = item;
  }
  return byGame.values.toList();
}

/// One game reduced to just the signals the recommender scores on.
class RecGame {
  final String title;
  final String systemName;
  final String filePath;
  final int? gameId; // RA game identity; same across copies in different folders
  final int total; // total achievements in the set
  final int earned; // achievements the user has earned (casual)
  final int hardcoreEarned; // achievements earned in hardcore mode
  final int players; // community size (casual players)

  const RecGame({
    required this.title,
    required this.systemName,
    required this.filePath,
    this.gameId,
    required this.total,
    required this.earned,
    this.hardcoreEarned = 0,
    required this.players,
  });

  int get remaining => total - earned;
  double get ratio => achievementFraction(earned, total);
  double get hardcoreRatio => achievementFraction(hardcoreEarned, total);
  bool get mastered => total > 0 && earned >= total;
  bool get hardcoreMastered => total > 0 && hardcoreEarned >= total;
  bool get unplayed => earned == 0;
}

/// Three ranked "what should I play next?" lists.
class Recommendations {
  final List<RecGame> closestToMastery;
  final List<RecGame> popularUnplayed;
  final List<RecGame> hardcoreReclears;

  const Recommendations({
    required this.closestToMastery,
    required this.popularUnplayed,
    required this.hardcoreReclears,
  });

  bool get isEmpty =>
      closestToMastery.isEmpty &&
      popularUnplayed.isEmpty &&
      hardcoreReclears.isEmpty;
}

/// Turns the scanned, supported library into next-best-game suggestions.
/// Pure, no I/O. Only games with an achievement set (total > 0) are scored.
class Recommender {
  Recommender._();

  static Recommendations build(List<RecGame> games, {int limit = 10}) {
    final supported = dedupeByGame(
      games.where((g) => g.total > 0),
      key: (g) => g.gameId ?? g.filePath,
      earned: (g) => g.earned,
    );

    // Started but not finished, highest completion first; the fastest masteries.
    final closest = supported
        .where((g) => g.earned > 0 && !g.mastered)
        .toList()
      ..sort((a, b) {
        final byRatio = b.ratio.compareTo(a.ratio);
        return byRatio != 0 ? byRatio : a.remaining.compareTo(b.remaining);
      });

    // Unplayed, biggest community first; the popular ones you're missing.
    final popular = supported.where((g) => g.unplayed).toList()
      ..sort((a, b) => b.players.compareTo(a.players));

    // Mastered on casual but not hardcore: quick hardcore re-clears, closest
    // to hardcore mastery first.
    final hardcore = supported
        .where((g) => g.mastered && !g.hardcoreMastered)
        .toList()
      ..sort((a, b) => b.hardcoreRatio.compareTo(a.hardcoreRatio));

    return Recommendations(
      closestToMastery: closest.take(limit).toList(),
      popularUnplayed: popular.take(limit).toList(),
      hardcoreReclears: hardcore.take(limit).toList(),
    );
  }
}
