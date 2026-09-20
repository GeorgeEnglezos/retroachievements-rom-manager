import 'dart:io';

import 'package:flutter/material.dart';

import '../models/folder_stats.dart' show achievementFraction, compactCount;
import '../models/rom_result.dart';
import '../models/scraped_game.dart';
import '../services/cull_deck_builder.dart';
import '../services/playlist_store.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'game_detail_dialog.dart';
import 'image_viewer.dart';
import 'ra_image.dart';
import 'rom_badges.dart';
import 'rom_thumb.dart';
import 'ui/ui_card.dart';
import 'ui/ui_progress_bar.dart';

/// One elimination-game card: art, listing thumbnail, title, file name,
/// achievements and metadata, with the search button supplied by the deck. The
/// console is not repeated here, the deck's app bar already names it. Tapping any image
/// enlarges it in place; the detail dialog opens from the info button beside
/// the search one. Given a wide card (desktop), the cover shares the art area
/// with every other image the game has and an achievement readout.
///
/// Artwork is shown whole (letterboxed on its own panel) rather than cropped to
/// fill: a keep-or-trash call is made off the picture, so cutting the edges off
/// a cover would be hiding the thing being judged.
class CullCard extends StatelessWidget {
  final CullCardData card;
  final VoidCallback onSearch;
  // Lets the host deck advance past a ROM deleted from within the dialog.
  final VoidCallback? onDeleted;

  const CullCard({
    super.key,
    required this.card,
    required this.onSearch,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final rom = card.rom;
    // One lookup, shared by the art fallback and the meta line gap-fill below.
    final scraped = ScrapedStore.instance.get(rom.filePath);
    final metaLine = _metaLine(rom, scraped);
    return UiCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 700
                  ? _gallery(ui, rom, scraped)
                  : _buildArt(ui, rom, scraped),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RomThumb(rom: rom, size: 56, raArt: rom.imageIcon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(card.title,
                              style: ui.display.copyWith(fontSize: 18),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          // An unmatched ROM titles itself from its file name,
                          // so only show the line when it says something new.
                          if (rom.fileName != card.title)
                            Text(rom.fileName,
                                style: ui.body
                                    .copyWith(fontSize: 11, color: ui.muted),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    UiFocusZoom(
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Search Google',
                        onPressed: onSearch,
                      ),
                    ),
                    _detailsButton(context, rom, scraped),
                  ],
                ),
                const SizedBox(height: 6),
                // Capped to a single scrollable run: an unbounded Wrap can grow
                // several lines tall with many tag badges and starve the art
                // above it (or overflow), so this row never grows past one line.
                SizedBox(
                  height: 28,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final b in _badges(rom, ui))
                        Padding(
                            padding: const EdgeInsets.only(right: 6), child: b),
                    ],
                  ),
                ),
                if (metaLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(metaLine,
                      style: ui.body.copyWith(fontSize: 11, color: ui.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsButton(
          BuildContext context, RomResult rom, ScrapedGame? scraped) =>
      UiFocusZoom(
        child: IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'Game details',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => GameDetailDialog(
              rom: rom,
              store: PlaylistStore(),
              discs: card.discs.length > 1 ? card.discs : null,
              scraped: scraped,
              onDeleted: onDeleted,
            ),
          ),
        ),
      );

  List<Widget> _badges(RomResult rom, UiTokens ui) => [
        ?achBadge(rom, ui),
        ?noAchBadge(rom),
        ?hotBadge(rom),
        ?discBadge(card.discs.length, ui),
        ...tagBadges(rom.fileName),
      ];

  // RA box art first; else imported (Skraper) box art on disk; else a
  // placeholder icon. Same lookup/fallback chain as RomThumb.
  Widget _buildArt(UiTokens ui, RomResult rom, ScrapedGame? scraped) {
    if (rom.boxArt != null) {
      return _panel(
        ui,
        RaImage(
          url: raImageUrl(rom.boxArt!),
          fit: BoxFit.contain,
          zoomable: true,
          error: _placeholder(ui),
          placeholder: const Center(
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    final scrapedArt = scraped?.thumbPath;
    if (scrapedArt != null) {
      return _localImage(
        ui,
        scrapedArt,
        // Decode at a bounded width instead of native resolution: scraper
        // PNGs are full covers and this card is never wider than that on any
        // supported platform, so a full-res decode would just waste memory.
        cacheWidth: 600,
      );
    }
    return _placeholder(ui);
  }

  // The ground a whole-image render sits on, so the letterbox bands around a
  // portrait cover read as part of the card instead of a gap.
  Widget _panel(UiTokens ui, Widget child) => ColoredBox(
        color: ui.trough,
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      );

  // Imported (Skraper) media from disk, tap-to-zoom like [RaImage] does for RA
  // art. The viewer gets the undecoded file so zooming isn't capped at the
  // thumbnail's decode width.
  Widget _localImage(UiTokens ui, String path,
          {required int cacheWidth, double errorIcon = 64}) =>
      Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showImageViewer(context, FileImage(File(path))),
          child: _panel(
            ui,
            Image.file(
              File(path),
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              errorBuilder: (_, _, _) => _placeholder(ui, icon: errorIcon),
            ),
          ),
        ),
      );

  Widget _placeholder(UiTokens ui, {double icon = 64}) => Container(
        color: ui.trough,
        child: Center(
          child:
              Icon(Icons.videogame_asset_outlined, size: icon, color: ui.muted),
        ),
      );

  // Wide card (desktop): the cover keeps the hero slot, and the column beside
  // it carries every other image the game has plus the achievement readout the
  // keep-or-trash call actually turns on. Falls back to the plain cover when the
  // game has neither.
  Widget _gallery(UiTokens ui, RomResult rom, ScrapedGame? scraped) {
    final extras = _extraImages(rom, scraped);
    final panel = _achievements(ui, rom);
    if (extras.isEmpty && panel == null) return _buildArt(ui, rom, scraped);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _buildArt(ui, rom, scraped)),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (extras.isNotEmpty)
                Expanded(
                  child: GridView.count(
                    crossAxisCount: extras.length > 2 ? 2 : 1,
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 4 / 3,
                    children: [for (final e in extras) _shot(ui, e)],
                  ),
                ),
              if (extras.isNotEmpty && panel != null) const SizedBox(height: 6),
              ?panel,
            ],
          ),
        ),
      ],
    );
  }

  // Set size and how far in the user already is, in the same slot every card
  // puts it. Null when the game has no set to report on.
  Widget? _achievements(UiTokens ui, RomResult rom) {
    final total = rom.achievementCount ?? 0;
    if (total == 0) return null;
    final earned = rom.earnedAchievements ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ui.surfaceAlt,
        borderRadius: ui.roundMd,
        border: Border.all(color: ui.border, width: ui.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ACHIEVEMENTS',
              style: ui.labelCaps.copyWith(color: ui.muted, fontSize: 10)),
          const SizedBox(height: 4),
          Text('$earned/$total', style: ui.mono.copyWith(fontSize: 22)),
          const SizedBox(height: 10),
          UiProgressBar(
              value: achievementFraction(earned, total),
              height: 5,
              color: ui.accentGames),
        ],
      ),
    );
  }

  // Every image besides the hero cover: RA's title-screen and in-game shots,
  // then imported (Skraper) media, minus video and minus the file the hero is
  // already showing. The RA icon is left out, it has its own slot beside the
  // title. Records are (path, isLocalFile).
  List<(String, bool)> _extraImages(RomResult rom, ScrapedGame? scraped) {
    final heroLocal = rom.boxArt == null ? scraped?.thumbPath : null;
    final keys = scraped == null
        ? const <String>[]
        : (scraped.images.keys.where((k) => k != 'video').toList()..sort());
    return [
      if (rom.imageTitle != null) (rom.imageTitle!, false),
      if (rom.imageIngame != null) (rom.imageIngame!, false),
      for (final k in keys)
        if (scraped!.images[k] != heroLocal) (scraped.images[k]!, true),
    ];
  }

  Widget _shot(UiTokens ui, (String, bool) shot) {
    final (path, isLocal) = shot;
    if (!isLocal) {
      return _panel(
        ui,
        RaImage(
          url: raImageUrl(path),
          fit: BoxFit.contain,
          zoomable: true,
          error: _placeholder(ui, icon: 24),
        ),
      );
    }
    return _localImage(ui, path, cacheWidth: 400, errorIcon: 24);
  }

  // "Genre · 1997 · Publisher · 350 pts · 1.2K players · 12.3 MB", filling RA
  // gaps from imported metadata and skipping missing parts.
  String _metaLine(RomResult rom, ScrapedGame? scraped) => [
        raOrScraped(rom.genre, scraped?.genre),
        raOrScraped(rom.released, scraped?.releaseDate),
        raOrScraped(rom.publisher, scraped?.publisher) ??
            raOrScraped(rom.developer, scraped?.developer),
        if ((rom.points ?? 0) > 0) '${rom.points} pts',
        if ((rom.numPlayersCasual ?? 0) > 0)
          '${compactCount(rom.numPlayersCasual!)} players',
        rom.fileSizeLabel,
      ].whereType<String>().join(' · ');
}
