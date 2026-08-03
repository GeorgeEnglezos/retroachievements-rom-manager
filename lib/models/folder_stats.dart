// In-memory stats for a single subfolder, shown on the home grid. Rebuilt from
// the home index on each read (not persisted itself).
class FolderStats {
  final String path;
  int totalGames; // number of ROM files found
  int totalSizeBytes; // combined size of those ROM files
  int gamesWithAchievements; // ROMs confirmed to have achievements (last scan)
  int gamesScanned; // ROMs resolved (supported + unsupported) last scan
  DateTime? lastScanned;

  FolderStats({
    required this.path,
    this.totalGames = 0,
    this.totalSizeBytes = 0,
    this.gamesWithAchievements = 0,
    this.gamesScanned = 0,
    this.lastScanned,
  });

  // Percentage of games that have achievements, or null if never scanned.
  double? get achievementPercent => lastScanned == null || totalGames == 0
      ? null
      : gamesWithAchievements * 100 / totalGames;
}

String formatBytes(int bytes) {
  const kb = 1 << 10, mb = 1 << 20, gb = 1 << 30;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}
