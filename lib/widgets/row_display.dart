/// Per-screen preset controlling which elements a `RomRowTile` renders. Every
/// capability lives in the tile; screens pick the preset they want.
enum RowDisplay {
  /// Full ROM listing (folder / search / playlist).
  roms,

  /// Folder's grouped-duplicates view: the grouping already conveys
  /// duplication, so a per-row DUP badge would be redundant.
  groupedRoms,

  /// Storage rows: a proportional size bar + drill chevron, no box art,
  /// progress or chips.
  storage;

  bool get isStorage => this == storage;
  bool get showDupBadge => this != groupedRoms;
}
