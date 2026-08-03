import '../models/fetch_plan.dart';

/// Maps a [FetchScope] to the folders a global run should process.
/// ROM-level filtering (unfetched-only) is the Match sub-option's job, applied
/// later in the runner, scope only selects folders.
List<String> resolveScopeFolders({
  required FetchScope scope,
  required List<String> allFolders,
  required List<String> changedFolders,
  required Set<String> unfetchedFolders,
}) {
  switch (scope) {
    case FetchScope.all:
      return allFolders;
    case FetchScope.changedFolders:
      return allFolders.where(changedFolders.contains).toList();
    case FetchScope.unfetchedFolders:
      return allFolders.where(unfetchedFolders.contains).toList();
  }
}
