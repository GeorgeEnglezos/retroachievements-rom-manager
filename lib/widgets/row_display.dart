/// Per-screen flags controlling which elements a `RomRowTile` renders. Every
/// capability lives in the tile; screens hide what they don't want.
class RowDisplay {
  final bool showBoxArt;
  final bool showProgress;
  final bool showSizeBar;
  final bool showChips;
  final bool showSelection;
  final bool showChevron;
  // Off in folder's grouped-duplicates view, where the grouping already conveys
  // duplication so a per-row DUP badge would be redundant.
  final bool showDupBadge;

  const RowDisplay({
    this.showBoxArt = true,
    this.showProgress = true,
    this.showSizeBar = false,
    this.showChips = true,
    this.showSelection = false,
    this.showChevron = false,
    this.showDupBadge = true,
  });

  RowDisplay copyWith({bool? showDupBadge}) => RowDisplay(
        showBoxArt: showBoxArt,
        showProgress: showProgress,
        showSizeBar: showSizeBar,
        showChips: showChips,
        showSelection: showSelection,
        showChevron: showChevron,
        showDupBadge: showDupBadge ?? this.showDupBadge,
      );

  /// Full ROM listing (folder / search / playlist).
  static const roms = RowDisplay(showSelection: true);

  /// Storage rows: a proportional size bar + drill chevron, no box art/progress.
  static const storage = RowDisplay(
    showBoxArt: false,
    showProgress: false,
    showChips: false,
    showSizeBar: true,
    showSelection: true,
    showChevron: true,
  );
}
