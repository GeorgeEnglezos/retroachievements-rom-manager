import '../models/game_entry.dart';
import 'incremental_scan.dart';

/// The result of classifying every known system folder against the disk on boot.
class FolderFreshness {
  /// Folders that were scanned before but whose directory is now gone (drive
  /// unmounted, folder deleted/renamed). Their cached data is kept; search just
  /// hides them so results never point at files that no longer exist.
  final List<String> gone;

  /// Folders that still exist but whose ROM files changed (added/removed/resized)
  /// since the stored scan; their JSON is stale and worth re-fetching.
  final List<String> changed;

  const FolderFreshness({required this.gone, required this.changed});

  bool get hasStale => gone.isNotEmpty || changed.isNotEmpty;
}

/// Classifies each system folder as gone, changed, or fresh. [currentSizes]
/// is injected so this stays filesystem-free. A never-scanned folder counts as
/// changed when it holds files, and as fresh when it is empty.
FolderFreshness classifyFolders({
  required List<String> systemPaths,
  required List<GameEntry> Function(String systemPath) storedGames,
  required bool Function(String systemPath) folderExists,
  required Map<String, int> Function(String systemPath) currentSizes,
}) {
  final gone = <String>[];
  final changed = <String>[];
  for (final path in systemPaths) {
    if (!folderExists(path)) {
      gone.add(path);
      continue;
    }
    final stored = storedGames(path);
    if (stored.isEmpty) {
      // Never scanned. A folder with ROMs on disk is the most changed a
      // folder can be; skipping it here is what let a newly added system
      // fall out of every narrow-scope sweep.
      if (currentSizes(path).isNotEmpty) changed.add(path);
      continue;
    }
    if (!folderUnchanged(stored, currentSizes(path))) changed.add(path);
  }
  return FolderFreshness(gone: gone, changed: changed);
}
