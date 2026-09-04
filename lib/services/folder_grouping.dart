import '../models/folder_stats.dart';
import '../models/home_sort.dart';
import 'console_map.dart';

/// One row in the home grid when "Combine systems" is on: either a real console
/// group (consoleId != null, one or more folders) or a single unknown-console
/// folder (consoleId == null, exactly one path).
class ConsoleGroup {
  final int? consoleId;
  final List<String> folderPaths;
  const ConsoleGroup({required this.consoleId, required this.folderPaths});
}

/// Groups folders by console id; null-id folders stay solo, listed last.
List<ConsoleGroup> groupFoldersByConsoleId(
    List<String> paths, Map<String, int?> consoleIds) {
  final byId = <int, List<String>>{};
  final order = <int>[];
  final unknown = <ConsoleGroup>[];
  for (final path in paths) {
    final id = consoleIds[path];
    if (id == null) {
      unknown.add(ConsoleGroup(consoleId: null, folderPaths: [path]));
    } else {
      if (!byId.containsKey(id)) order.add(id);
      byId.putIfAbsent(id, () => []).add(path);
    }
  }
  return [
    for (final id in order)
      ConsoleGroup(consoleId: id, folderPaths: byId[id]!),
    ...unknown,
  ];
}

/// Sums a group's stats. [lastScanned] is null if ANY folder is unscanned,
/// so the percentage only shows for fully-scanned groups.
FolderStats aggregateFolderStats(int consoleId, List<FolderStats> stats) {
  final agg = FolderStats(path: 'console:$consoleId');
  DateTime? earliest;
  var anyUnscanned = stats.isEmpty;
  for (final s in stats) {
    agg.totalGames += s.totalGames;
    agg.totalSizeBytes += s.totalSizeBytes;
    agg.gamesScanned += s.gamesScanned;
    agg.gamesWithAchievements += s.gamesWithAchievements;
    final ls = s.lastScanned;
    if (ls == null) {
      anyUnscanned = true;
    } else if (earliest == null || ls.isBefore(earliest)) {
      earliest = ls;
    }
  }
  agg.lastScanned = anyUnscanned ? null : earliest;
  return agg;
}

/// Orders a home-grid item by [sort], projecting it to the keys each mode needs
/// (so both plain folders and combined console groups share one comparator).
int compareByHomeSort<T>(
  T a,
  T b, {
  required HomeSort sort,
  required String Function(T) name,
  required int Function(T) sizeBytes,
  required int Function(T) gameCount,
  required int? Function(T) consoleId,
}) {
  switch (sort) {
    case HomeSort.alphabetical:
      return name(a).toLowerCase().compareTo(name(b).toLowerCase());
    case HomeSort.size:
      return sizeBytes(b).compareTo(sizeBytes(a));
    case HomeSort.fileCount:
      return gameCount(b).compareTo(gameCount(a));
    case HomeSort.system:
      final ka = ConsoleMap.manufacturerSortKey(consoleId(a));
      final kb = ConsoleMap.manufacturerSortKey(consoleId(b));
      if (ka != kb) return ka.compareTo(kb);
      return name(a).toLowerCase().compareTo(name(b).toLowerCase());
  }
}
