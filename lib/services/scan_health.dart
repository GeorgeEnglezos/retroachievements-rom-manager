import '../models/home_index.dart';

/// Aggregated, decision-oriented counts for the whole scanned library.
/// Pure: computed from the home index (no disk walk, no network).
class ScanHealth {
  final int totalRoms;
  final int supported; // matched to an RA game with achievements
  final int unsupported; // confirmed no RA match
  final int notFetched; // not yet looked up
  final int withProgress; // at least one achievement earned
  final int systems;
  final int totalSizeBytes;

  const ScanHealth({
    required this.totalRoms,
    required this.supported,
    required this.unsupported,
    required this.notFetched,
    required this.withProgress,
    required this.systems,
    required this.totalSizeBytes,
  });

  factory ScanHealth.fromIndex(
    List<SystemSummary> systems,
    List<SearchIndexEntry> searchIndex,
  ) {
    var supported = 0, unsupported = 0, notFetched = 0, withProgress = 0;
    for (final e in searchIndex) {
      if (e.matched) {
        supported++;
      } else if (e.noMatch) {
        unsupported++;
      } else {
        notFetched++;
      }
      if ((e.earnedAchievements ?? 0) > 0) withProgress++;
    }
    return ScanHealth(
      totalRoms: searchIndex.length,
      supported: supported,
      unsupported: unsupported,
      notFetched: notFetched,
      withProgress: withProgress,
      systems: systems.length,
      totalSizeBytes:
          systems.fold(0, (sum, s) => sum + s.totalSizeBytes),
    );
  }

  /// Supported share of everything that has actually been looked up. Returns 0
  /// when nothing is resolved yet (avoids a divide-by-zero in the UI).
  double get supportedRatio {
    final resolved = supported + unsupported;
    return resolved == 0 ? 0 : supported / resolved;
  }
}
