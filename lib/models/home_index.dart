/// Per-system summary shown on the home grid (no disk walk needed to render).
class SystemSummary {
  final String systemPath;
  final String systemId;
  final String name;
  final int? consoleId;
  final int totalGames;
  final int gamesScanned;
  final int gamesWithAchievements;
  final int totalSizeBytes;
  final DateTime? lastScanned;

  SystemSummary({
    required this.systemPath,
    required this.systemId,
    required this.name,
    required this.consoleId,
    required this.totalGames,
    required this.gamesScanned,
    required this.gamesWithAchievements,
    required this.totalSizeBytes,
    required this.lastScanned,
  });
}

/// One lean row per ROM, enough to render a search result and group it by
/// system, and to compute the "Played" playlist (earnedAchievements > 0).
/// Full game detail is loaded from the system file on tap.
class SearchIndexEntry {
  final String? title;
  final String fileName;
  final String filePath;
  final String systemPath;
  final String systemName;
  final int? gameId;
  final bool matched;
  final bool noMatch;
  final String? md5;
  final String? icon;
  final int? earnedAchievements;
  final int? achievementCount;
  final int? fileSize;

  SearchIndexEntry({
    required this.title,
    required this.fileName,
    required this.filePath,
    required this.systemPath,
    required this.systemName,
    required this.gameId,
    required this.matched,
    required this.noMatch,
    required this.md5,
    required this.icon,
    required this.earnedAchievements,
    this.achievementCount,
    this.fileSize,
  });
}
