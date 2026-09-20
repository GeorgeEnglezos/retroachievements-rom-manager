
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_result.dart';
import '../models/rom_row.dart';
import '../services/disc_formats.dart';
import '../services/member_key.dart';
import '../services/play_view.dart';
import '../services/playlist_store.dart';
import '../services/rom_tap.dart';
import '../theme/ui_tokens.dart';
import 'game_detail_dialog.dart';
import 'ui/ui_card.dart';
import 'rom_actions.dart';
import 'rom_badges.dart';
import 'rom_progress.dart';
import 'rom_thumb.dart';
import 'row_display.dart';

/// A single list-row tile that renders any [RomRow], gating each visual element
/// on the [RowDisplay] flag set. Decoupled from [RomResult] (it reads a
/// [RomRow]) so the storage screen can reuse the same tile.
///
/// The row is three lines at most: title with its chips beside it, one mono
/// meta line (file name, size), then progress with its read on the same line.
class RomRowTile extends StatelessWidget {
  /// Side of the leading thumbnail.
  static const _art = 64.0;

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

  /// Drawn in the thumbnail slot instead of the row's own art. Storage rows use
  /// it for the console logo / matched-game icon they resolve themselves.
  final Widget? leading;

  const RomRowTile({
    super.key,
    required this.row,
    required this.display,
    required this.store,
    this.leading,
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
    final isFavorite =
        row.rom != null &&
        store.isFavorite(
          memberKeyFor(gameId: row.rom!.gameId, filePath: row.rom!.filePath),
        );
    final cardColor = isSelected
        ? ui.accent.withValues(alpha: 0.12)
        : isFavorite
        ? ui.favoriteFill
        : null;
    // Favorite rows are accent-filled, so their labels flip to ui.favoriteInk
    // (the ground colour) to read against the fill.
    final fg = isFavorite ? ui.favoriteInk : null;
    Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: UiCard(
        padding: EdgeInsets.zero,
        color: cardColor,
        focusScale:
            1.0, // wide row: ring only, no lift (would overflow the list)
        flourish: FocusFlourish.jump, // rows: a light hop, not the tile tilt
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
    } else if (row.rom == null) {
      // Storage folders and other non-game rows: navigation only.
      row.onTap?.call();
    } else if (row.onTap != null &&
        romTapListenable.value != RomTapAction.play) {
      // A screen-supplied open (search hit, multi-disc group) still wins while
      // clicks open details; on Play the launch takes over.
      row.onTap!();
    } else {
      openRomOnTap(
        context,
        row.rom!,
        store: store,
        onDeleted: onDeleted,
        onPlaylistChanged: onPlaylistChanged,
        onFetch: onFetch,
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
              // The trough, so the proportion reads as a filled bar behind the
              // row rather than a coloured highlight over it.
              child: ColoredBox(color: ui.trough),
            ),
          ),
          content,
        ],
      );
    }

    return content;
  }

  Widget _tileContent(BuildContext context, UiTokens ui, Color? fg) {
    final chips = display.showChips ? _chips(ui) : <Widget>[];
    final subtitle = _buildSubtitle(context, ui, fg);
    final title = Text(
      row.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: fg),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildLeading(ui),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chips ride beside the title rather than on a line of their
                // own; a long name pushes them to the next run instead of
                // overflowing. Wrap bounds its children to the row width, so
                // the title still ellipsises.
                if (chips.isEmpty)
                  title
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [title, ...chips],
                  ),
                ?subtitle,
              ],
            ),
          ),
          if (row.scoreLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              row.scoreLabel!,
              style: ui.mono.copyWith(fontSize: 13, color: fg),
            ),
          ],
          if (display.showSizeBar && row.sizeLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              row.sizeLabel!,
              style: ui.mono.copyWith(fontSize: 12, color: fg),
            ),
          ],
          if (display.showChevron && row.showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: fg ?? ui.text),
          ],
        ],
      ),
    );
  }

  Widget _buildLeading(UiTokens ui) {
    Widget base;
    final rom = row.rom;
    if (leading != null) {
      base = SizedBox(width: _art, height: _art, child: leading);
    } else if (rom == null) {
      base = const SizedBox.shrink();
    } else if (!display.showBoxArt) {
      base = romStatusIcon(rom);
    } else {
      base = RomThumb(rom: rom, size: _art, raArt: row.imageIcon);
    }

    if (!display.showSelection || !isSelectMode) return base;
    return SizedBox(
      width: _art,
      height: _art,
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

  Widget? _buildProgress(BuildContext context, Color? fg) {
    // Small screens (phones in any orientation, or any narrow window) drop the
    // per-row bar: the row is too tight for a bar + label, and the earned/total
    // read in the meta line already carries how far in the game is.
    if (MediaQuery.sizeOf(context).shortestSide < kBreakCompact) return null;
    if (!display.showProgress ||
        row.rom == null ||
        row.earnedAchievements == null) {
      return null;
    }
    if (!RomProgress.hasProgress(row.rom!)) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: RomProgress(
        rom: row.rom!,
        barHeight: 4,
        labelSize: 10,
        inline: true,
        colorOverride: fg,
      ),
    );
  }

  /// The one mono line under the title. [parts] stay their own Text widgets
  /// rather than one joined string, so each remains findable, and they read as
  /// a single line either way.
  Widget? _metaLine(
    UiTokens ui,
    List<String?> parts, {
    Color? fg,
    Color? firstColor,
  }) {
    final shown = parts.whereType<String>().where((p) => p.isNotEmpty).toList();
    if (shown.isEmpty) return null;
    final style = TextStyle(fontSize: 11, color: fg ?? ui.muted);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) Text('  ·  ', style: style),
            Flexible(
              child: Text(
                shown[i],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: i == 0 && firstColor != null && fg == null
                    ? style.copyWith(color: firstColor)
                    : style,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context, UiTokens ui, Color? fg) {
    if (row.rom == null) {
      return row.subtitle != null
          ? Text(row.subtitle!, style: TextStyle(color: fg))
          : null;
    }

    final rom = row.rom!;
    // Size lives in the subtitle for ROM rows only; the storage screen draws its
    // own via display.showSizeBar, which play mode never touches.
    final sizeLabel = playView.fileSize ? row.sizeLabel : null;

    // localOnly renders like a supported row minus RA data: filename title,
    // size, no achievements/progress and no "Not fetched" status text.
    if (rom.status == RomStatus.supported || rom.isLocalOnly) {
      final fileName =
          playView.fileName && row.subtitle != null && row.subtitle != row.title
          ? row.subtitle
          : null;
      // The same earned/total read the grid's GameMetaRow shows, inline in the
      // meta line alongside any progress bar below.
      final total = rom.achievementCount ?? 0;
      final achLabel = playView.achievementCount && total > 0
          ? '${rom.earnedAchievements ?? 0}/$total'
          : null;
      final meta = _metaLine(ui, [fileName, sizeLabel, achLabel], fg: fg);
      final progress = _buildProgress(context, fg);
      if (meta == null && progress == null) return null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [?meta, ?progress],
      );
    }

    final statusText = switch (rom.status) {
      RomStatus.supported ||
      RomStatus.localOnly ||
      RomStatus.metadataOnly =>
        null,
      // The row has the width for the fix, not just the diagnosis.
      RomStatus.unsupportedFormat => DiscFormats.isNkit(rom.filePath)
          ? 'NKit format not supported'
          : 'Compressed disc. Add Dolphin in Settings → Emulators to hash it',
      RomStatus.error => rom.errorMessage ?? statusLabel(rom.status),
      final s => statusLabel(s),
    };
    if (statusText == null) return null;
    return _metaLine(
      ui,
      [statusText, sizeLabel],
      fg: fg,
      firstColor:
          rom.status == RomStatus.error ||
              rom.status == RomStatus.unsupportedFormat
          ? ui.warning
          : null,
    );
  }

  List<Widget> _chips(UiTokens ui) {
    if (!display.showChips || row.rom == null) return [];
    final rom = row.rom!;
    return [
      ?discBadge(row.discCount, ui, fileName: rom.fileName),
      if (display.showDupBadge) ?dupBadge(rom, ui),
      ?hotBadge(rom),
      ?noAchBadge(rom),
      ...tagBadges(rom.fileName),
    ];
  }
}
