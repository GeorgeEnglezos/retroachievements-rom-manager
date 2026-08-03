import 'package:flutter/material.dart';
import '../models/folder_sort.dart';
import '../services/cleanup_score.dart';
import '../services/rom_filter.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_button.dart';
import 'ui/ui_chip.dart';
import 'ui/ui_dropdown.dart';
import 'ui/ui_search_field.dart';
import 'ui/ui_segmented.dart';
import 'active_filter_chips.dart';
import 'filter_panel.dart';

/// Full-width, GB-themed two-tier folder toolbar. Owns the search field and the
/// inline filter panel; all sort/view/duplicates/actions state lives in the
/// parent and flows in via props + callbacks.
class FolderToolbar extends StatefulWidget {
  final RomFilter filter;
  final FolderSort sort;
  final bool sortAscending;
  final bool gridView;
  final List<String> availableGenres;
  final List<String> availableTags;
  final bool showProgress;
  final bool anyDuplicates;
  final bool hot;
  final bool showHot;
  final CleanupScoreMode cleanupMode;
  final List<({String id, String name})> playlists;
  // The cross-system "All games" view hides the fetch/hash Actions button.
  final bool showActions;
  final bool actionsEnabled;
  final ValueChanged<RomFilter> onFilterChanged;
  final ValueChanged<FolderSort> onSortChanged;
  final ValueChanged<CleanupScoreMode> onCleanupModeChanged;
  final VoidCallback onDirectionToggle;
  final VoidCallback onViewToggle;
  final ValueChanged<bool> onDuplicatesToggle;
  final ValueChanged<bool> onHotToggle;
  final VoidCallback onRunActions;

  const FolderToolbar({
    super.key,
    required this.filter,
    required this.sort,
    required this.sortAscending,
    required this.gridView,
    required this.availableGenres,
    this.availableTags = const [],
    required this.showProgress,
    required this.anyDuplicates,
    this.hot = false,
    this.showHot = false,
    this.cleanupMode = CleanupScoreMode.logDampened,
    required this.playlists,
    this.showActions = true,
    required this.actionsEnabled,
    required this.onFilterChanged,
    required this.onSortChanged,
    this.onCleanupModeChanged = _ignoreMode,
    required this.onDirectionToggle,
    required this.onViewToggle,
    required this.onDuplicatesToggle,
    required this.onHotToggle,
    required this.onRunActions,
  });

  static void _ignoreMode(CleanupScoreMode _) {}

  @override
  State<FolderToolbar> createState() => _FolderToolbarState();
}

class _FolderToolbarState extends State<FolderToolbar> {
  bool _expanded = false;
  final _textController = TextEditingController();

  bool get _dupActive => widget.filter.onlyDuplicates;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.filter.text;
  }

  @override
  void didUpdateWidget(FolderToolbar old) {
    super.didUpdateWidget(old);
    if (old.filter.text != widget.filter.text &&
        _textController.text != widget.filter.text) {
      _textController.text = widget.filter.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<FolderSort> get _sortOptions => [
        FolderSort.alphabetical,
        FolderSort.achievementCount,
        FolderSort.points,
        FolderSort.progress,
        FolderSort.lastPlayed,
        FolderSort.cleanup,
      ];

  bool get _cleanupActive =>
      widget.sort == FolderSort.cleanup && !_dupActive && !widget.hot;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: ui.surface,
        border: Border(
            bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow1(),
          const SizedBox(height: 8),
          _buildRow2(),
          if (_expanded) ...[
            const SizedBox(height: 8),
            // Cap + scroll the panel so an expanded filter list can't push the
            // toolbar taller than the screen (vertical overflow on phones).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
              ),
              child: SingleChildScrollView(
                child: FilterPanel(
                  filter: widget.filter,
                  availableGenres: widget.availableGenres,
                  availableTags: widget.availableTags,
                  showProgress: widget.showProgress,
                  playlists: widget.playlists,
                  onChanged: widget.onFilterChanged,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow1() {
    return Row(
      children: [
        Expanded(
          child: UiSearchField(
            controller: _textController,
            hintText: 'Search name or title',
            onChanged: (v) =>
                widget.onFilterChanged(widget.filter.copyWith(text: v)),
          ),
        ),
        if (widget.showActions) ...[
          const SizedBox(width: 8),
          UiButton(
            label: 'Actions',
            onPressed: widget.actionsEnabled ? widget.onRunActions : null,
          ),
        ],
      ],
    );
  }

  Widget _buildRow2() {
    final ui = context.ui;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('SORT', style: ui.labelCaps.copyWith(color: ui.muted)),
        UiDropdown<FolderSort>(
          value: _sortOptions.contains(widget.sort)
              ? widget.sort
              : FolderSort.alphabetical,
          enabled: !_dupActive && !widget.hot,
          items: [
            for (final s in _sortOptions)
              (value: s, label: folderSortLabel(s)),
          ],
          onChanged: widget.onSortChanged,
        ),
        UiSegmented<bool>(
          value: widget.sortAscending,
          enabled: !_dupActive && !widget.hot,
          segments: const [
            (value: true, label: '', icon: Icons.arrow_upward),
            (value: false, label: '', icon: Icons.arrow_downward),
          ],
          // Only fire when the tapped segment differs from the current value, so
          // re-tapping the active direction doesn't flip it.
          onChanged: (v) {
            if (v != widget.sortAscending) widget.onDirectionToggle();
          },
        ),
        UiSegmented<bool>(
          value: widget.gridView,
          segments: const [
            (value: false, label: '', icon: Icons.view_list),
            (value: true, label: '', icon: Icons.grid_view),
          ],
          onChanged: (v) {
            if (v != widget.gridView) widget.onViewToggle();
          },
        ),
        if (_cleanupActive) ..._buildCleanupControls(ui),
        if (widget.anyDuplicates)
          UiChip(
            label: 'Duplicates',
            icon: Icons.copy_all,
            selected: _dupActive,
            onTap: () => widget.onDuplicatesToggle(!_dupActive),
          ),
        if (widget.showHot)
          UiChip(
            label: 'Hot',
            icon: Icons.local_fire_department,
            selected: widget.hot,
            onTap: () => widget.onHotToggle(!widget.hot),
          ),
        ...activeFilterChips(
          filter: widget.filter,
          playlists: widget.playlists,
          onChanged: widget.onFilterChanged,
        ),
        UiChip(
          label: 'Filters',
          icon: _expanded ? Icons.expand_less : Icons.tune,
          selected: _expanded,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }

  // Scoring mode picker. Only rendered while the Cleanup sort is active.
  List<Widget> _buildCleanupControls(UiTokens ui) => [
        UiDropdown<CleanupScoreMode>(
          value: widget.cleanupMode,
          items: [
            for (final m in CleanupScoreMode.values)
              (value: m, label: cleanupModeLabel(m)),
          ],
          onChanged: widget.onCleanupModeChanged,
        ),
      ];
}
