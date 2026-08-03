import '../models/game_entry.dart';

/// Whether [g] already has a usable result for [consoleId], so an
/// unfetched-only run can skip it. A `noMatch` recorded under a *different*
/// console id is stale (the file was hashed as the wrong system), so it counts
/// as unresolved and gets re-hashed.
bool isResolvedEntry(GameEntry? g, int? consoleId) =>
    g != null && (g.matched || (g.noMatch && g.hashConsoleId == consoleId));

/// Unchanged = scanned before, same path set, same sizes (null stored size
/// counts as a match). Lets incremental rescans skip the folder.
bool folderUnchanged(
  List<GameEntry> stored,
  Map<String, int> currentSizeByPath,
) {
  if (stored.isEmpty) return false; // never scanned → scan it
  if (stored.length != currentSizeByPath.length) return false; // added/removed
  for (final g in stored) {
    final size = currentSizeByPath[g.filePath];
    if (size == null) return false; // a stored file is gone or renamed
    if (g.fileSize != null && g.fileSize != size) return false; // edited
  }
  return true;
}
