import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_focusable.dart';

/// GB-styled bulk selection bar. Shows either delete progress or the selection
/// count + bulk actions (favorites / playlist / delete / exclude / close).
/// Null action callbacks hide their button.
class BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final bool deleting;
  final int deleteDone;
  final int deleteTotal;
  final VoidCallback? onFavorites;
  final VoidCallback? onPlaylist;
  final VoidCallback onDelete;
  final VoidCallback? onExclude;
  final VoidCallback onClose;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.deleting,
    required this.deleteDone,
    required this.deleteTotal,
    this.onFavorites,
    this.onPlaylist,
    required this.onDelete,
    this.onExclude,
    required this.onClose,
  });

  /// Foreground on the two solid-filled buttons (purple favorite, red delete):
  /// white reads cleanly on both fills in either palette.
  static const Color _onFill = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      key: const ValueKey('bulk-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.surfaceAlt,
        border: Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: deleting ? _deletingRow(ui) : _actionsRow(ui),
    );
  }

  Widget _deletingRow(UiTokens ui) => Row(
        children: [
          Text('Deleting $deleteDone of $deleteTotal…',
              style: ui.mono.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: deleteTotal == 0 ? null : deleteDone / deleteTotal,
              color: ui.accent,
              backgroundColor: ui.trough,
            ),
          ),
        ],
      );

  Widget _actionsRow(UiTokens ui) => Row(
        children: [
          Text('$selectedCount selected',
              style: ui.mono.copyWith(fontWeight: FontWeight.w900)),
          const Spacer(),
          if (onFavorites != null)
            _btn(ui, Icons.favorite, 'Favorites', onFavorites,
                fill: kFavoriteColor),
          if (onPlaylist != null)
            _btn(ui, Icons.playlist_add, 'Playlist', onPlaylist),
          _btn(ui, Icons.delete_outline, 'Delete', onDelete, fill: kDangerColor),
          if (onExclude != null) _btn(ui, Icons.block, 'Exclude', onExclude),
          UiFocusZoom(
            child: IconButton(
              icon: Icon(Icons.close, size: 18, color: ui.text),
              // The only bare icon on the bar; the rest carry visible text.
              tooltip: 'Clear selection',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ),
        ],
      );

  Widget _btn(UiTokens ui, IconData icon, String label, VoidCallback? onTap,
      {Color? fill}) {
    // Favorite (purple) and Delete (red) are solid filled buttons with white
    // text so they read cleanly against the bar instead of clashing.
    if (fill != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: UiFocusZoom(
          child: TextButton.icon(
            icon: Icon(icon, size: 16, color: _onFill),
            label: Text(label,
                style: ui.labelCaps.copyWith(color: _onFill, fontWeight: FontWeight.w900)),
            style: TextButton.styleFrom(
              backgroundColor: fill,
              shape: RoundedRectangleBorder(borderRadius: ui.roundMd),
            ),
            onPressed: onTap,
          ),
        ),
      );
    }
    final color = onTap == null ? ui.muted : ui.text;
    return UiFocusZoom(
      child: TextButton.icon(
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: ui.labelCaps.copyWith(color: color, fontWeight: FontWeight.w900)),
        onPressed: onTap,
      ),
    );
  }
}
