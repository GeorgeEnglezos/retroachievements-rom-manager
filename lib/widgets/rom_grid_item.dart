import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_result.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'game_detail_dialog.dart';
import 'ui/ui_card.dart';
import 'rom_actions.dart';
import 'rom_badges.dart';
import 'rom_progress.dart';
import 'rom_thumb.dart';

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
    final displayTitle = gameDisplayName(rom.gameTitle, rom.fileName);
    final badges = _badges(ui);
    final chips = _chips();
    final isFavorite = store
        .isFavorite(memberKeyFor(gameId: rom.gameId, filePath: rom.filePath));
    // Favorite cards flip their labels to ui.favoriteText (white on the light
    // theme's black wash; unchanged on dark).
    final fg = isFavorite ? ui.favoriteText : null;
    return GestureDetector(
      onSecondaryTapDown: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      onLongPressStart: (d) =>
          _actions.showContextMenu(context, d.globalPosition),
      child: UiCard(
        padding: EdgeInsets.zero,
        color: isFavorite ? ui.favoriteHighlight : null,
        onTap: () {
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
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: _buildLeading()),
                  const SizedBox(height: 6),
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displayTitle != rom.fileName)
                    Text(
                      rom.fileName,
                      style: TextStyle(fontSize: 9, color: fg ?? Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  ..._buildGridStatus(ui, fg),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: badges,
                    ),
                  ],
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: chips,
                    ),
                  ],
                ],
              ),
            ),
            if (isSelectMode)
              Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  child: Container(
                    // Same colors as the list tile's selection dot.
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ui.accent
                          : ui.text.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGridStatus(UiTokens ui, Color? fg) {
    // local-only: just the size line, no RA status label above it.
    if (rom.isLocalOnly) {
      return [
        if (rom.fileSizeLabel != null)
          Text(rom.fileSizeLabel!,
              style: TextStyle(fontSize: 9, color: fg ?? ui.muted)),
      ];
    }
    if (rom.status == RomStatus.supported) {
      final out = <Widget>[];
      if (RomProgress.hasProgress(rom)) {
        out.add(RomProgress(rom: rom));
        out.add(const SizedBox(height: 3));
      }
      final ach = achBadge(rom, ui);
      if (ach != null) out.add(ach);
      if (rom.fileSizeLabel != null) {
        out.add(
          Text(
            rom.fileSizeLabel!,
            style: TextStyle(fontSize: 9, color: fg ?? ui.muted),
          ),
        );
      }
      return out;
    }
    final label = switch (rom.status) {
      RomStatus.notFetched => 'Not fetched',
      RomStatus.checking => 'Checking...',
      RomStatus.unsupported => 'No achievements',
      RomStatus.unsupportedFormat => 'Bad format',
      RomStatus.error => rom.errorMessage ?? 'Error',
      _ => '',
    };
    final out = <Widget>[
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: fg ?? (rom.status == RomStatus.error ? ui.warning : ui.muted),
        ),
      ),
    ];
    if (rom.fileSizeLabel != null) {
      out.add(
        Text(
          rom.fileSizeLabel!,
          style: TextStyle(fontSize: 9, color: fg ?? ui.muted),
        ),
      );
    }
    return out;
  }

  Widget _buildLeading() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxHeight.isFinite
            ? constraints.maxHeight * 0.9
            : constraints.maxWidth * 0.9;
        return Center(
            child: RomThumb(rom: rom, size: size, raArt: rom.thumbArt));
      },
    );
  }

  List<Widget> _badges(UiTokens ui) =>
      [?discBadge(discCount, ui), ?dupBadge(rom, ui)];

  List<Widget> _chips() => [
    ?hotBadge(rom),
    ?noAchBadge(rom),
    ...tagBadges(rom.fileName),
  ];
}
