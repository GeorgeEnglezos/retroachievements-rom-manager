import '../models/game_entry.dart';
import '../models/home_index.dart';
import '../models/system_data.dart';

/// Builds the home-grid [SystemSummary] for a system. `gamesScanned` counts
/// games that were resolved either way (matched or confirmed no-match), matching
/// the existing folder-stats semantics. [keep] drops games the user has
/// excluded or ignored so the grid counts match the filtered folder listing.
SystemSummary buildSummary(
  SystemData data, {
  required String systemId,
  required String name,
  required int? consoleId,
  bool Function(GameEntry g)? keep,
}) {
  final games =
      keep == null ? data.games : data.games.where(keep).toList();
  var scanned = 0;
  var withAch = 0;
  var bytes = 0;
  DateTime? last;
  for (final g in games) {
    if (g.matched || g.noMatch) scanned++;
    if (g.matched) withAch++;
    bytes += g.fileSize ?? 0;
    if (last == null || g.lastScanned.isAfter(last)) last = g.lastScanned;
  }
  return SystemSummary(
    systemPath: data.systemPath,
    systemId: systemId,
    name: name,
    consoleId: consoleId,
    totalGames: games.length,
    gamesScanned: scanned,
    gamesWithAchievements: withAch,
    totalSizeBytes: bytes,
    lastScanned: games.isEmpty ? null : last,
  );
}

/// Builds the lean search-index rows for a system's games. [keep] drops games
/// the user has excluded or ignored so search never surfaces them.
List<SearchIndexEntry> buildSearchRows(
  SystemData data, {
  required String systemName,
  bool Function(GameEntry g)? keep,
}) {
  return [
    for (final g in data.games)
      if (keep == null || keep(g))
      SearchIndexEntry(
        title: g.gameInfo?.title,
        fileName: g.fileName,
        filePath: g.filePath,
        systemPath: data.systemPath,
        systemName: systemName,
        gameId: g.gameId,
        matched: g.matched,
        noMatch: g.noMatch,
        md5: g.md5,
        icon: g.gameInfo?.imageIcon,
        earnedAchievements: g.progress?.earnedAchievements,
        achievementCount: g.gameInfo?.achievementCount,
        fileSize: g.fileSize,
      ),
  ];
}
