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

/// The one game tile, shared by Home and the library grid.
///
/// The library grid ([lean] false, the default) is the full-featured tile: a
/// [UiCard] with the achievement numbers + chips, a muted status/size line, and
/// the accent favorite fill — plus tap, the context menu, and multi-select.
/// Home passes [lean] true for the bare, framed cover with just the numbers and
/// console (its clean shelf), keeping the same behavior. Progress reads the way
/// Home shows it either way: a trophy or a strip on the art.
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
  // Home's lean shelf: bare framed art, numbers + console, no card/chips/status.
  final bool lean;
  // Fixed cell size (Home's square shelf). Null lets the art fill the grid cell.
  final double? height;
  final double? width;

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
    this.lean = false,
    this.height,
    this.width,
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
    final fileName = playView.fileName && displayTitle != rom.fileName
        ? rom.fileName
        : null;

    if (lean) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(context),
        onSecondaryTapDown: (d) =>
            _actions.showContextMenu(context, d.globalPosition),
        onLongPressStart: (d) =>
            _actions.showContextMenu(context, d.globalPosition),
        child: GameCover(
          rom: rom,
          height: height,
          width: width,
          fileName: fileName,
          artOverlays: [?discBadge(discCount, ui), ?dupBadge(rom, ui)],
          corner: isSelectMode ? _selectionDot(ui) : null,
          meta: _leanMeta(ui),
        ),
      );
    }

    final isFavorite = store
        .isFavorite(memberKeyFor(gameId: rom.gameId, filePath: rom.filePath));
    // Favorite cards are accent-filled, so their labels flip to ui.favoriteInk
    // (the ground colour) to read against the fill.
    final fg = isFavorite ? ui.favoriteInk : null;
    final subline = _subline(ui);
    return GestureDetector(
      onSecondaryTapDown: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      child: UiCard(
        padding: EdgeInsets.zero,
        color: isFavorite ? ui.favoriteFill : null,
        onTap: () => _onTap(context),
        child: GameCover(
          rom: rom,
          framedArt: false,
          foreground: fg,
          textPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          fileName: fileName,
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

  /// Home's meta line: `earned/total` in the mono/olive, then the console name.
  /// The numbers drop when the set has none, so an unmatched tile shows just its
  /// console.
  Widget _leanMeta(UiTokens ui) {
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final console = rom.consoleName ?? '';
    return Row(
      children: [
        if (total > 0)
          Text('$earned/$total',
              style: ui.mono.copyWith(fontSize: 11, color: ui.accentGames)),
        Expanded(
          child: Text(total > 0 ? '  ·  $console' : console,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: ui.muted)),
        ),
      ],
    );
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

  // No achBadge here: GameMetaRow already shows the count as `earned/total`,
  // and the height-capped meta row would clip a trailing "N ACH" chip anyway.
  List<Widget> _chips(UiTokens ui) => [
    ?hotBadge(rom),
    ?noAchBadge(rom),
    ...tagBadges(rom.fileName),
  ];
}
