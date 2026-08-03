import 'package:flutter/material.dart';
import '../theme/ui_tokens.dart';

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

  /// Foreground (text/icons) on the bar: white reads cleanly on the
  /// dark/blue bar background in both palettes.
  static const Color _onBar = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      key: const ValueKey('bulk-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ui.text,
        border: Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: deleting ? _deletingRow(ui) : _actionsRow(ui),
    );
  }

  Widget _deletingRow(UiTokens ui) => Row(
        children: [
          Text('Deleting $deleteDone of $deleteTotal…',
              style: ui.mono.copyWith(color: _onBar, fontWeight: FontWeight.w900)),
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
              style: ui.mono.copyWith(color: _onBar, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (onFavorites != null)
            _btn(ui, Icons.favorite, 'Favorites', onFavorites,
                fill: kFavoriteColor),
          if (onPlaylist != null)
            _btn(ui, Icons.playlist_add, 'Playlist', onPlaylist),
          _btn(ui, Icons.delete_outline, 'Delete', onDelete, fill: kDangerColor),
          if (onExclude != null) _btn(ui, Icons.block, 'Exclude', onExclude),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: _onBar),
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      );

  Widget _btn(UiTokens ui, IconData icon, String label, VoidCallback? onTap,
      {Color? fill}) {
    // Favorite (pink) and Delete (red) are solid filled buttons with white text
    // so they read cleanly against the blue bar instead of clashing.
    if (fill != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton.icon(
          icon: Icon(icon, size: 16, color: _onBar),
          label: Text(label,
              style: ui.labelCaps.copyWith(color: _onBar, fontWeight: FontWeight.w900)),
          style: TextButton.styleFrom(
            backgroundColor: fill,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onPressed: onTap,
        ),
      );
    }
    final color = onTap == null ? ui.muted : _onBar;
    return TextButton.icon(
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: ui.labelCaps.copyWith(color: color, fontWeight: FontWeight.w900)),
      onPressed: onTap,
    );
  }
}
