import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_result.dart';
import '../services/member_key.dart';
import '../services/play_view.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'game_cover.dart';
import 'game_detail_dialog.dart';
import 'ui/ui_card.dart';
import 'rom_actions.dart';
import 'rom_badges.dart';

/// One tile in the library grid: the shared [GameCover] wrapped with the grid's
/// own behavior (selection, context menu, favorites) and its richer meta line —
/// the Home-style achievement numbers followed by the chips, then a muted
/// status/size line. Progress reads the way Home shows it: a trophy or a strip
/// on the art, no bar in the text.
class RomGridItem extends StatelessWidget {
  final RomResult rom;
  final PlaylistStore store;
  final VoidCallback? onDeleted;
  final VoidCallback? onExcluded;
  final VoidCallback? onPlaylistChanged;
  final VoidCallback? onFetch;
  final bool isSelected;
  final bool isSelectMode;
  final void Function({required bool isShift})? onSelectToggle;
  final void Function(String action)? onSelectionAction;
  // Non-null for a multi-disc listing: opens the group dialog instead of the
  // single-ROM one, and [discCount] renders a disc badge.
  final VoidCallback? onOpen;
  final int? discCount;
  final List<String>? groupPaths;

  const RomGridItem({
    super.key,
    required this.rom,
    required this.store,
    this.onDeleted,
    this.onExcluded,
    this.onPlaylistChanged,
    this.onFetch,
    this.isSelected = false,
    this.isSelectMode = false,
    this.onSelectToggle,
    this.onSelectionAction,
    this.onOpen,
    this.discCount,
    this.groupPaths,
  });

  RomActions get _actions => RomActions(
    rom: rom,
    store: store,
    onDeleted: onDeleted,
    onExcluded: onExcluded,
    onPlaylistChanged: onPlaylistChanged,
    onFetch: onFetch,
    isSelected: isSelected,
    onSelectionAction: onSelectionAction,
    groupPaths: groupPaths,
  );

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final displayTitle = listingTitle(rom.gameTitle, rom.fileName);
    final isFavorite = store
        .isFavorite(memberKeyFor(gameId: rom.gameId, filePath: rom.filePath));
    // Favorite cards flip their labels to ui.favoriteText (white on the light
    // theme's black wash; unchanged on dark).
    final fg = isFavorite ? ui.favoriteText : null;

    final subline = _subline(ui);
    return GestureDetector(
      onSecondaryTapDown: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      child: UiCard(
        padding: EdgeInsets.zero,
        color: isFavorite ? ui.favoriteHighlight : null,
        onTap: () => _onTap(context),
        child: GameCover(
          rom: rom,
          framedArt: false,
          foreground: fg,
          textPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          fileName: playView.fileName && displayTitle != rom.fileName
              ? rom.fileName
              : null,
          artOverlays: [?discBadge(discCount, ui), ?dupBadge(rom, ui)],
          corner: isSelectMode ? _selectionDot(ui) : null,
          meta: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GameMetaRow(rom: rom, numberColor: fg, trailing: _chips(ui)),
              if (subline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: fg ?? _sublineColor(ui)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (ctrl || shift || isSelectMode) {
      onSelectToggle?.call(isShift: shift);
    } else if (onOpen != null) {
      onOpen!();
    } else if (canOpenDetail(rom)) {
      showDialog(
        context: context,
        builder: (_) => GameDetailDialog(
          rom: rom,
          store: store,
          onDeleted: onDeleted,
          onPlaylistChanged: onPlaylistChanged,
          onFetch: onFetch,
          scraped: ScrapedStore.instance.get(rom.filePath),
        ),
      );
    }
  }

  /// The muted line under the meta row: the fetch status (only where there is
  /// one to report) then the file size, both play-mode gated the way the list
  /// tile gates them. Null when neither applies.
  String? _subline(UiTokens ui) {
    final size = playView.fileSize ? rom.fileSizeLabel : null;
    final status = rom.isLocalOnly || rom.status == RomStatus.supported
        ? null
        : switch (rom.status) {
            RomStatus.notFetched => 'Not fetched',
            RomStatus.checking => 'Checking...',
            RomStatus.unsupported => 'No achievements',
            RomStatus.unsupportedFormat => 'Bad format',
            RomStatus.error => rom.errorMessage ?? 'Error',
            _ => null,
          };
    final parts = [?status, ?size];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  Color _sublineColor(UiTokens ui) =>
      rom.status == RomStatus.error ? ui.warning : ui.muted;

  Widget _selectionDot(UiTokens ui) => IgnorePointer(
        child: Container(
          // Same colors as the list tile's selection dot.
          decoration: BoxDecoration(
            color: isSelected ? ui.accent : ui.text.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: Colors.white,
            size: 22,
          ),
        ),
      );

  List<Widget> _chips(UiTokens ui) => [
    ?achBadge(rom, ui),
    ?hotBadge(rom),
    ?noAchBadge(rom),
    ...tagBadges(rom.fileName),
  ];
}
