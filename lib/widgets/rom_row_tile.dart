import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_result.dart';
import '../models/rom_row.dart';
import '../services/disc_formats.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'game_detail_dialog.dart';
import 'ui/ui_card.dart';
import 'ra_image.dart';
import 'rom_actions.dart';
import 'rom_badges.dart';
import 'rom_progress.dart';
import 'row_display.dart';

/// A single list-row tile that renders any [RomRow], gating each visual element
/// on the [RowDisplay] flag set. Decoupled from [RomResult] (it reads a
/// [RomRow]) so the storage screen can reuse the same tile.
class RomRowTile extends StatelessWidget {
  final RomRow row;
  final RowDisplay display;
  final PlaylistStore store;
  final bool isSelected;
  final bool isSelectMode;
  final void Function({required bool isShift})? onSelectToggle;
  final void Function(String action)? onSelectionAction;
  final VoidCallback? onDeleted;
  final VoidCallback? onExcluded;
  final VoidCallback? onPlaylistChanged;
  final VoidCallback? onFetch;
  final VoidCallback? onDismissDuplicate;
  final Color? groupColor;

  const RomRowTile({
    super.key,
    required this.row,
    required this.display,
    required this.store,
    this.isSelected = false,
    this.isSelectMode = false,
    this.onSelectToggle,
    this.onSelectionAction,
    this.onDeleted,
    this.onExcluded,
    this.onPlaylistChanged,
    this.onFetch,
    this.onDismissDuplicate,
    this.groupColor,
  });

  RomActions get _actions => RomActions(
    rom: row.rom!,
    store: store,
    onDeleted: onDeleted,
    onExcluded: onExcluded,
    onPlaylistChanged: onPlaylistChanged,
    onFetch: onFetch,
    onDismissDuplicate: onDismissDuplicate,
    isSelected: isSelected,
    onSelectionAction: onSelectionAction,
    groupPaths: row.groupPaths,
  );

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final isFavorite = row.rom != null &&
        store.isFavorite(
            memberKeyFor(gameId: row.rom!.gameId, filePath: row.rom!.filePath));
    final cardColor = isSelected
        ? ui.accent.withValues(alpha: 0.12)
        : isFavorite
            ? ui.favoriteHighlight
            : null;
    // Favorite rows flip their labels to ui.favoriteText (white on the light
    // theme's black wash; unchanged on dark).
    final fg = isFavorite ? ui.favoriteText : null;
    Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: UiCard(
        padding: EdgeInsets.zero,
        color: cardColor,
        onTap: () => _onTap(context),
        child: _buildCardContent(context, ui, fg),
      ),
    );

    if (row.rom != null) {
      final actions = _actions;
      body = GestureDetector(
        onSecondaryTapDown: (d) =>
            actions.showContextMenu(context, d.globalPosition),
        onLongPressStart: (d) =>
            actions.showContextMenu(context, d.globalPosition),
        child: body,
      );
    }

    return body;
  }

  void _onTap(BuildContext context) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (ctrl || shift || isSelectMode) {
      onSelectToggle?.call(isShift: shift);
    } else if (row.onTap != null) {
      row.onTap!();
    } else if (row.rom != null && canOpenDetail(row.rom!)) {
      showDialog(
        context: context,
        builder: (_) => GameDetailDialog(
          rom: row.rom!,
          store: store,
          onDeleted: onDeleted,
          onPlaylistChanged: onPlaylistChanged,
          onFetch: onFetch,
          scraped: ScrapedStore.instance.get(row.rom!.filePath),
        ),
      );
    }
  }

  Widget _buildCardContent(BuildContext context, UiTokens ui, Color? fg) {
    Widget content = groupColor == null
        ? _tileContent(context, ui, fg)
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: groupColor),
                Expanded(child: _tileContent(context, ui, fg)),
              ],
            ),
          );

    if (display.showSizeBar && row.sizeFraction != null) {
      content = Stack(
        children: [
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: row.sizeFraction!.clamp(0.0, 1.0),
              child: ColoredBox(color: ui.accent.withValues(alpha: 0.25)),
            ),
          ),
          content,
        ],
      );
    }

    return content;
  }

  Widget _tileContent(BuildContext context, UiTokens ui, Color? fg) {
    final subtitle = _buildSubtitle(ui, fg);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLeading(ui),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: fg),
                ),
                ?subtitle,
              ],
            ),
          ),
          if (row.scoreLabel != null) ...[
            const SizedBox(width: 8),
            Text(row.scoreLabel!,
                style: ui.mono.copyWith(fontSize: 13, color: fg)),
          ],
          if (display.showSizeBar && row.sizeLabel != null) ...[
            const SizedBox(width: 8),
            Text(row.sizeLabel!,
                style: ui.mono.copyWith(fontSize: 12, color: fg)),
          ],
          if (display.showChevron && row.showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: fg ?? ui.text),
          ],
        ],
      ),
    );
  }

  // In-memory map lookup (no I/O): the store is loaded once at startup.
  String? _scrapedThumbPath() {
    final path = row.rom?.filePath ?? row.filePath;
    if (path == null) return null;
    return ScrapedStore.instance.get(path)?.thumbPath;
  }

  Widget _buildLeading(UiTokens ui) {
    Widget base;
    final scrapedArt = display.showBoxArt ? _scrapedThumbPath() : null;
    if (display.showBoxArt &&
        (row.status == RomStatus.supported ||
            row.status == RomStatus.metadataOnly) &&
        row.imageIcon != null) {
      base = RaImage(
        url: raImageUrl(row.imageIcon!),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(4),
        error: row.rom != null
            ? romStatusIcon(row.rom!)
            : const SizedBox.shrink(),
        placeholder: const SizedBox(
          width: 80,
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (scrapedArt != null) {
      // No RA art. Fall back to imported (Skraper) box art on disk.
      base = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(scrapedArt),
          width: 80,
          height: 80,
          // Decode at thumbnail size, scraper PNGs are full covers and would
          // otherwise fill the image cache at native resolution per row.
          cacheWidth: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => row.rom != null
              ? romStatusIcon(row.rom!)
              : const SizedBox.shrink(),
        ),
      );
    } else if (row.rom != null) {
      base = romStatusIcon(row.rom!);
    } else {
      base = const SizedBox.shrink();
    }

    if (!display.showSelection || !isSelectMode) return base;
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          base,
          Positioned(
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
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
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget? _buildProgress() {
    if (!display.showProgress ||
        row.rom == null ||
        row.earnedAchievements == null) {
      return null;
    }
    if (!RomProgress.hasProgress(row.rom!)) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RomProgress(rom: row.rom!, barHeight: 4, labelSize: 10),
    );
  }

  Widget _sizeLine(
    UiTokens ui,
    String text, {
    Color? fg,
    List<Widget> chips = const [],
    TextStyle? style,
  }) {
    style = (style ?? const TextStyle()).copyWith(color: fg);
    if (chips.isEmpty) {
      return Text(text, overflow: TextOverflow.ellipsis, style: style);
    }
    return Row(
      children: [
        Flexible(
          child: Text(text, overflow: TextOverflow.ellipsis, style: style),
        ),
        const SizedBox(width: 8),
        // Flexible so the chip strip gets a bounded width and wraps to a new run
        // on narrow (mobile) rows instead of overflowing the Row.
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
        ),
      ],
    );
  }

  Widget? _buildSubtitle(UiTokens ui, Color? fg) {
    if (row.rom == null) {
      return row.subtitle != null
          ? Text(row.subtitle!, style: TextStyle(color: fg))
          : null;
    }

    final rom = row.rom!;
    final sizeSuffix = row.sizeLabel != null ? '  ·  ${row.sizeLabel}' : '';
    final chips = display.showChips ? _chips(ui) : <Widget>[];

    // localOnly renders like a supported row minus RA data: filename title,
    // size + chips, no achievements/progress and no "Not fetched" status text.
    if (rom.status == RomStatus.supported || rom.isLocalOnly) {
      final progress = _buildProgress();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.subtitle != null && row.subtitle != row.title)
            Text(
              row.subtitle!,
              style: TextStyle(fontSize: 11, color: fg ?? ui.muted),
            ),
          _sizeLine(ui, row.sizeLabel ?? '', fg: fg, chips: chips),
          ?progress,
        ],
      );
    }

    final statusText = switch (rom.status) {
      RomStatus.notFetched => 'Not fetched',
      RomStatus.checking => 'Checking...',
      RomStatus.unsupported => 'No achievements found',
      RomStatus.unsupportedFormat => DiscFormats.isNkit(rom.filePath)
          ? 'NKit format not supported'
          : 'Compressed disc. Add Dolphin in Settings → Emulators to hash it',
      RomStatus.error => rom.errorMessage ?? 'Unknown error',
      _ => null,
    };
    if (statusText == null) return null;
    return _sizeLine(
      ui,
      '$statusText$sizeSuffix',
      fg: fg,
      chips: chips,
      style: rom.status == RomStatus.error ||
              rom.status == RomStatus.unsupportedFormat
          ? TextStyle(color: ui.warning)
          : null,
    );
  }

  List<Widget> _chips(UiTokens ui) {
    if (!display.showChips || row.rom == null) return [];
    final rom = row.rom!;
    return [
      ?discBadge(row.discCount, ui),
      if (display.showDupBadge) ?dupBadge(rom, ui),
      ?hotBadge(rom),
      ?achBadge(rom, ui),
      ?noAchBadge(rom),
      ...tagBadges(rom.fileName),
    ];
  }
}
