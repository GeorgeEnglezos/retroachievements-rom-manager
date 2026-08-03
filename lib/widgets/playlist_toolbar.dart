import 'package:flutter/material.dart';
import '../services/rom_filter.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_chip.dart';
import 'ui/ui_search_field.dart';
import 'ui/ui_segmented.dart';
import 'active_filter_chips.dart';
import 'filter_panel.dart';

/// GB-themed playlist toolbar: shared search + filter panel plus a
/// group-by-system toggle. No sort / actions / duplicates / grid.
class PlaylistToolbar extends StatefulWidget {
  final RomFilter filter;
  final List<String> availableGenres;
  final List<String> availableTags;
  final bool showProgress;
  final List<({String id, String name})> playlists;
  final bool grouped;
  final ValueChanged<RomFilter> onFilterChanged;
  final VoidCallback onGroupedToggle;

  const PlaylistToolbar({
    super.key,
    required this.filter,
    required this.availableGenres,
    this.availableTags = const [],
    required this.showProgress,
    required this.playlists,
    required this.grouped,
    required this.onFilterChanged,
    required this.onGroupedToggle,
  });

  @override
  State<PlaylistToolbar> createState() => _PlaylistToolbarState();
}

class _PlaylistToolbarState extends State<PlaylistToolbar> {
  bool _expanded = false;
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _textController.text = widget.filter.text;
  }

  @override
  void didUpdateWidget(PlaylistToolbar old) {
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

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      decoration: BoxDecoration(
        color: ui.background,
        border:
            Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: UiSearchField(
                  controller: _textController,
                  hintText: 'Search name or title',
                  onChanged: (v) =>
                      widget.onFilterChanged(widget.filter.copyWith(text: v)),
                ),
              ),
              const SizedBox(width: 8),
              UiSegmented<bool>(
                value: widget.grouped,
                segments: const [
                  (value: false, label: 'List', icon: Icons.view_list),
                  (value: true, label: 'By system', icon: Icons.category),
                ],
                onChanged: (v) {
                  if (v != widget.grouped) widget.onGroupedToggle();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            FilterPanel(
              filter: widget.filter,
              availableGenres: widget.availableGenres,
              availableTags: widget.availableTags,
              showProgress: widget.showProgress,
              playlists: widget.playlists,
              onChanged: widget.onFilterChanged,
            ),
          ],
        ],
      ),
    );
  }
}
