/// Which folders a global fetch run touches. Folder-level only; ROM-level
/// "unfetched vs all" lives in the Match sub-option, not here. Ignored in the
/// per-folder modal (single folder, no folder set to choose).
enum FetchScope { changedFolders, unfetchedFolders, all }

/// The user's choices from the fetch modal.
class FetchPlan {
  final FetchScope scope;
  final bool refresh; // re-walk disk for added/removed files first (no API)
  final bool refreshLists; // force a re-pull of each console's game/hash list,
  // overriding RaCache.listTtl, which normally handles this on its own
  final bool match; // hash ROMs + identify game on RA
  final bool matchReFetchAll; // false = only unfetched ROMs
  final bool progress; // sync achievement progress for matched games

  const FetchPlan({
    required this.scope,
    this.refresh = false,
    this.refreshLists = false,
    this.match = false,
    this.matchReFetchAll = false,
    this.progress = false,
  });
}
