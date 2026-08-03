import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_group.dart';
import '../models/rom_row.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/scan_settings.dart';
import '../services/selection_logic.dart';
import '../theme/ui_tokens.dart';
import 'bulk_action_bar.dart';
import 'confirm_recycle_dialog.dart';
import 'playlist_picker.dart';
import 'rom_grid_item.dart';
import 'rom_row_tile.dart';
import 'row_display.dart';

/// Shared list/grid widget that owns selection state, the bulk-action bar,
/// and delete-with-progress. Screens delegate rendering here and supply
/// callbacks for actions they support.
class RomListView extends StatefulWidget {
  final List<RomRow> rows;
  final List<RomGroup>? groups;
  // Optional per-row widget drawn in a fixed gutter to the LEFT of each tile,
  // outside its card. Index-aligned to [rows]; null entries reserve the gutter
  // so cards stay aligned. Flat lists only (storage's console/game icons).
  final List<Widget?>? leadings;
  final RowDisplay display;
  final PlaylistStore store;
  final String? Function(RomRow)? keyOf;
  final bool enableSelection;
  final bool gridView;
  final SliverGridDelegate? gridDelegate;
  final Future<bool> Function(RomRow)? onDeleteRow;
  final void Function(List<RomRow>)? onRowsRemoved;
  final void Function(List<RomRow>)? onSelectionChanged;
  // Bulk favorites/playlist run entirely in here (the store is at hand);
  // screens just opt in. Bulk exclude writes the excluded-files setting here,
  // then hands the rows to [onRowsExcluded] so the screen drops them.
  final bool bulkFavorites;
  final bool bulkPlaylist;
  final void Function(List<RomRow>)? onRowsExcluded;
  final void Function(RomRow)? onRowExcluded;
  final void Function(RomRow)? onRowFetch;
  final void Function(RomRow)? onRowDismissDuplicate;
  final VoidCallback? onPlaylistChanged;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Widget? emptyState;
  final EdgeInsetsGeometry? padding;
  @visibleForTesting final Set<String>? initialSelected;

  const RomListView({
    super.key,
    this.rows = const [],
    this.groups,
    this.leadings,
    required this.display,
    required this.store,
    this.keyOf,
    this.enableSelection = false,
    this.gridView = false,
    this.gridDelegate,
    this.onDeleteRow,
    this.onRowsRemoved,
    this.onSelectionChanged,
    this.bulkFavorites = false,
    this.bulkPlaylist = false,
    this.onRowsExcluded,
    this.onRowExcluded,
    this.onRowFetch,
    this.onRowDismissDuplicate,
    this.onPlaylistChanged,
    this.shrinkWrap = false,
    this.physics,
    this.emptyState,
    this.padding,
    this.initialSelected,
  });

  @override
  State<RomListView> createState() => _RomListViewState();
}

class _RomListViewState extends State<RomListView> {
  final Set<String> _selected = {};
  // Group labels the user folded away. Labels are unique per grouping, and the
  // set is view-only state, so it isn't persisted.
  final Set<String> _collapsed = {};
  String? _lastSelected;
  bool _deleting = false;
  int _deleteDone = 0;
  int _deleteTotal = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelected != null) {
      _selected.addAll(widget.initialSelected!);
    }
  }

  @override
  void didUpdateWidget(RomListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rows can change in place (without a new widget key). Drop selection keys
    // whose row is gone so the internal set and the mirrored parent selection
    // don't hold stale paths.
    if (_selected.isEmpty) return;
    final present = _sortedKeys.toSet();
    final before = _selected.length;
    _selected.retainWhere(present.contains);
    if (_lastSelected != null && !present.contains(_lastSelected)) {
      _lastSelected = null;
    }
    if (_selected.length != before) {
      // Notifying the parent synchronously here would setState mid-build; defer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emitSelection();
      });
    }
  }

  String? _key(RomRow r) => (widget.keyOf ?? (x) => x.filePath)(r);

  List<RomRow> get _flatRows {
    final g = widget.groups;
    if (g != null) return [for (final grp in g) ...grp.rows];
    return widget.rows;
  }

  List<String> get _sortedKeys =>
      _flatRows.map(_key).whereType<String>().toList();

  void _toggle(String key, bool isShift) {
    final result = resolveSelection(
      current: _selected,
      sortedPaths: _sortedKeys,
      tapped: key,
      lastSelected: _lastSelected,
      isShift: isShift,
    );
    setState(() {
      _selected
        ..clear()
        ..addAll(result.selected);
      _lastSelected = result.lastSelected;
    });
    _emitSelection();
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _lastSelected = null;
    });
    _emitSelection();
  }

  void _emitSelection() {
    widget.onSelectionChanged
        ?.call(_flatRows.where((r) => _selected.contains(_key(r))).toList());
  }

  List<RomRow> get _selectedRows =>
      _flatRows.where((r) => _selected.contains(_key(r))).toList();

  String _memberKey(RomRow r) =>
      memberKeyFor(gameId: r.rom?.gameId, filePath: r.filePath!);

  Future<void> _bulkFavorites() async {
    final targets = _selectedRows;
    if (targets.isEmpty) return;
    var added = 0, removed = 0;
    for (final r in targets) {
      if (await widget.store.toggleMember(favoritesId, _memberKey(r))) {
        added++;
      } else {
        removed++;
      }
    }
    if (!mounted) return;
    widget.onPlaylistChanged?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(favoritesSnack(added, removed))),
    );
  }

  Future<void> _bulkPlaylist() async {
    final keys = _selectedRows.map(_memberKey).toList();
    if (keys.isEmpty) return;
    await PlaylistPicker.showBulk(context, widget.store, keys);
    if (!mounted) return;
    widget.onPlaylistChanged?.call();
  }

  Future<void> _bulkExclude() async {
    final targets = _selectedRows;
    if (targets.isEmpty) return;
    await ScanSettings.addExcludedFiles(
        [for (final r in targets) ...(r.groupPaths ?? [r.filePath!])]);
    if (!mounted) return;
    widget.onRowsExcluded!(targets);
  }

  Future<void> _runDelete() async {
    if (widget.onDeleteRow == null) return;
    final targets = _selectedRows;
    final ok = await confirmRecycleDialog(
        context, deleteConfirmMessage(files: targets.length));
    if (!ok || !mounted) return;
    setState(() {
      _deleting = true;
      _deleteDone = 0;
      _deleteTotal = targets.length;
      _selected.clear();
      _lastSelected = null;
    });
    _emitSelection();
    final removed = <RomRow>[];
    for (final row in targets) {
      final gone = await widget.onDeleteRow!(row);
      if (!mounted) return;
      setState(() {
        _deleteDone++;
        if (gone) removed.add(row);
      });
    }
    if (!mounted) return;
    setState(() => _deleting = false);
    widget.onRowsRemoved?.call(removed);
  }

  // tile wiring helpers

  bool _isSelected(RomRow r) {
    final k = _key(r);
    return k != null && _selected.contains(k);
  }

  void Function({required bool isShift})? _selectToggle(RomRow r) {
    if (!widget.enableSelection) return null;
    final k = _key(r);
    if (k == null) return null;
    return ({required bool isShift}) => _toggle(k, isShift);
  }

  VoidCallback? _excludedCb(RomRow r) =>
      widget.onRowExcluded == null ? null : () => widget.onRowExcluded!(r);

  VoidCallback? _fetchCb(RomRow r) =>
      widget.onRowFetch == null ? null : () => widget.onRowFetch!(r);

  VoidCallback? _dismissDupCb(RomRow r) => widget.onRowDismissDuplicate == null
      ? null
      : () => widget.onRowDismissDuplicate!(r);

  // build

  @override
  Widget build(BuildContext context) {
    final showBar =
        widget.enableSelection && (_selected.isNotEmpty || _deleting);

    Widget list;
    if (_flatRows.isEmpty) {
      list = widget.emptyState ?? const SizedBox.shrink();
    } else if (widget.gridView) {
      list = _buildGrid();
    } else if (widget.groups != null) {
      list = _buildGrouped();
    } else {
      list = _buildFlat();
    }

    final column = Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showBar
              ? BulkActionBar(
                  selectedCount: _selected.length,
                  deleting: _deleting,
                  deleteDone: _deleteDone,
                  deleteTotal: _deleteTotal,
                  onFavorites: widget.bulkFavorites ? _bulkFavorites : null,
                  onPlaylist: widget.bulkPlaylist ? _bulkPlaylist : null,
                  onDelete: _runDelete,
                  onExclude:
                      widget.onRowsExcluded == null ? null : _bulkExclude,
                  onClose: _clearSelection,
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: list),
      ],
    );

    if (!widget.enableSelection) return column;
    return CallbackShortcuts(
      bindings: {
        // Esc clears the selection; Delete sends it to the Recycle Bin (which
        // still asks for confirmation). Both no-op when nothing is selected.
        const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_selected.isNotEmpty) _runDelete();
        },
      },
      child: Focus(autofocus: false, child: column),
    );
  }

  Widget _buildFlat() => ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding,
        itemCount: widget.rows.length,
        itemBuilder: (_, i) => _withLeading(i, _tile(widget.rows[i])),
      );

  // Wraps a tile with its left-gutter leading icon when [leadings] is supplied.
  Widget _withLeading(int i, Widget tile) {
    if (widget.leadings == null) return tile;
    final leading = i < widget.leadings!.length ? widget.leadings![i] : null;
    return Row(
      children: [
        SizedBox(width: 76, child: Center(child: leading)),
        Expanded(child: tile),
      ],
    );
  }

  Widget _buildGrouped() {
    final children = <Widget>[];
    for (final grp in widget.groups!) {
      final collapsed = _collapsed.contains(grp.label);
      children.add(_GroupHeader(
        group: grp,
        collapsed: collapsed,
        onTap: () => setState(() =>
            collapsed ? _collapsed.remove(grp.label) : _collapsed.add(grp.label)),
      ));
      if (collapsed) continue;
      for (var i = 0; i < grp.rows.length; i++) {
        final r = grp.rows[i];
        children.add(RomRowTile(
          row: r,
          display: widget.display,
          store: widget.store,
          isSelected: _isSelected(r),
          isSelectMode: _selected.isNotEmpty,
          onSelectToggle: _selectToggle(r),
          onDeleted: () => widget.onRowsRemoved?.call([r]),
          onExcluded: _excludedCb(r),
          onFetch: _fetchCb(r),
          onDismissDuplicate: _dismissDupCb(r),
          onPlaylistChanged: widget.onPlaylistChanged,
          groupColor: grp.color,
        ));
      }
    }
    return ListView(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: widget.padding,
      children: children,
    );
  }

  Widget _buildGrid() => GridView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: widget.padding,
        gridDelegate: widget.gridDelegate!,
        itemCount: _flatRows.length,
        itemBuilder: (_, i) {
          final r = _flatRows[i];
          return RomGridItem(
            rom: r.rom!,
            store: widget.store,
            isSelected: _isSelected(r),
            isSelectMode: _selected.isNotEmpty,
            onSelectToggle: _selectToggle(r),
            onDeleted: () => widget.onRowsRemoved?.call([r]),
            onExcluded: _excludedCb(r),
            onFetch: _fetchCb(r),
            onPlaylistChanged: widget.onPlaylistChanged,
            onOpen: r.onTap,
            discCount: r.discCount,
            groupPaths: r.groupPaths,
          );
        },
      );

  Widget _tile(RomRow r) => RomRowTile(
        row: r,
        display: widget.display,
        store: widget.store,
        isSelected: _isSelected(r),
        isSelectMode: _selected.isNotEmpty,
        onSelectToggle: _selectToggle(r),
        onDeleted: () => widget.onRowsRemoved?.call([r]),
        onExcluded: _excludedCb(r),
        onFetch: _fetchCb(r),
        onDismissDuplicate: _dismissDupCb(r),
        onPlaylistChanged: widget.onPlaylistChanged,
      );
}

/// Tappable section header for a grouped listing: accent stripe, label, row
/// count, and a chevron showing whether the section is folded away.
class _GroupHeader extends StatelessWidget {
  final RomGroup group;
  final bool collapsed;
  final VoidCallback onTap;

  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final style =
        ui.labelCaps.copyWith(color: ui.muted, fontWeight: FontWeight.w700);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18, color: ui.muted),
            const SizedBox(width: 4),
            if (group.color != null)
              Container(
                  width: 4,
                  height: 14,
                  color: group.color,
                  margin: const EdgeInsets.only(right: 6)),
            Expanded(child: Text(group.label, style: style)),
            Text('${group.rows.length}', style: style),
          ],
        ),
      ),
    );
  }
}
