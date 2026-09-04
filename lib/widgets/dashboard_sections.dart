import 'package:flutter/material.dart';
import '../models/rom_result.dart';
import '../services/play_view.dart';
import '../services/playlist_store.dart';
import '../theme/ui_tokens.dart';
import 'ra_image.dart';
import 'rom_grid_item.dart';
import 'ui/ui_progress_bar.dart';

/// The section layouts a phone can render a bucket of games with. Neither
/// scrolls sideways; the page itself is the only scroll surface. Wide windows
/// ignore this and always use a single row of covers.
enum DashboardLayout {
  /// Full-width rows: icon, title, console, progress.
  list,

  /// A fixed multi-column grid of covers.
  grid,
}

/// A titled block of cover tiles, cut to what the row can hold. Nothing scrolls
/// sideways: the section works out how many uniform cells fit across the width
/// and shows exactly that many games, so a bucket never trails off the edge.
/// The header still names the whole bucket's size.
///
/// [columns] pins the count (phones); leaving it null derives it from
/// [minTileWidth]. Renders nothing when [games] is empty, so a screen can list
/// several sections and only the ones with content show.
class DashboardCoverSection extends StatelessWidget {
  final String title;
  final List<RomResult> games;
  final void Function(RomResult rom) onOpen;

  /// Playlists for the tiles' favorite/playlist context actions. Defaults to the
  /// shared singleton.
  final PlaylistStore? store;

  /// Reload hook after a tile's context menu deletes a game or edits playlists.
  final VoidCallback? onChanged;

  /// Fixed column count. Null works it out from the width.
  final int? columns;

  /// Narrowest a derived cell may get before the section drops a column.
  final double minTileWidth;

  /// How many rows of cells to fill. The section shows at most
  /// `columns * rows` games.
  final int rows;

  const DashboardCoverSection({
    super.key,
    required this.title,
    required this.games,
    required this.onOpen,
    this.store,
    this.onChanged,
    this.columns,
    this.minTileWidth = 168,
    this.rows = 1,
  });

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(title: title),
        LayoutBuilder(builder: (context, c) {
          final cols = columns ??
              ((c.maxWidth + _gap) ~/ (minTileWidth + _gap)).clamp(1, 12);
          // Uniform square cells: the row trades the artwork's true ratio for
          // columns that line up.
          final tile = (c.maxWidth - _gap * (cols - 1)) / cols;
          final playlists = store ?? PlaylistStore();
          return Wrap(
            spacing: _gap,
            runSpacing: 16,
            children: [
              for (final rom in games.take(cols * rows))
                RomGridItem(
                  rom: rom,
                  store: playlists,
                  lean: true,
                  height: tile,
                  width: tile,
                  onOpen: () => onOpen(rom),
                  onDeleted: onChanged,
                  onPlaylistChanged: onChanged,
                ),
            ],
          );
        }),
      ],
    );
  }
}

/// The same bucket as full-width rows: icon, title, console, progress. Nothing
/// scrolls sideways, so the whole section reads in one vertical pass. Shows at
/// most [max] games because the page itself is the scroll surface.
class DashboardListSection extends StatelessWidget {
  final String title;
  final List<RomResult> games;
  final void Function(RomResult rom) onOpen;
  final int max;

  const DashboardListSection({
    super.key,
    required this.title,
    required this.games,
    required this.onOpen,
    this.max = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();
    final ui = context.ui;
    final shown = games.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(title: title),
        for (var i = 0; i < shown.length; i++) ...[
          // Hairlines between rows rather than gaps: the block reads as one
          // list instead of a stack of separate cards.
          if (i > 0) Divider(height: 1, thickness: 1, color: ui.border),
          _GameRow(rom: shown[i], onTap: () => onOpen(shown[i])),
        ],
      ],
    );
  }
}

/// Shared heading above every dashboard section: just the section name.
class DashboardSectionHeader extends StatelessWidget {
  final String title;

  const DashboardSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ui.display.copyWith(fontSize: 19)),
    );
  }
}

/// One full-width row in [DashboardListSection].
class _GameRow extends StatelessWidget {
  final RomResult rom;
  final VoidCallback onTap;

  const _GameRow({required this.rom, required this.onTap});

  static const _art = 44.0;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final title = listingTitle(rom.gameTitle, rom.fileName);
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final frac = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final art = rom.thumbArt ?? rom.boxArt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: ui.roundSm,
              child: SizedBox(
                width: _art,
                height: _art,
                child: art == null
                    ? ColoredBox(
                        color: ui.surfaceAlt,
                        child: Icon(Icons.videogame_asset,
                            size: 20, color: ui.muted),
                      )
                    : RaImage(
                        url: raImageUrl(art),
                        fit: BoxFit.cover,
                        placeholder: ColoredBox(color: ui.surfaceAlt),
                        error: ColoredBox(
                          color: ui.surfaceAlt,
                          child: Icon(Icons.videogame_asset,
                              size: 20, color: ui.muted),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('$earned/$total',
                          style: ui.mono
                              .copyWith(fontSize: 10, color: ui.accentGames)),
                      Expanded(
                        child: Text('  ·  ${rom.consoleName ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: ui.muted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Small screens drop the bar (this list only renders on phones):
            // the earned/total read below the title already carries progress.
            if (total > 0 &&
                MediaQuery.sizeOf(context).shortestSide >= 600) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                child: UiProgressBar(
                    value: frac, height: 4, color: ui.accentGames),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
