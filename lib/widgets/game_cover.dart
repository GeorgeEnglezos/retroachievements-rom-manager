import 'package:flutter/material.dart';
import '../models/rom_result.dart';
import '../services/play_view.dart';
import '../theme/ui_tokens.dart';
import 'rom_thumb.dart';

/// The shared game tile: full-bleed art with a mastery trophy or in-progress
/// strip over it, then the title and a caller-built [meta] line. Home uses it
/// lean (see [DashboardCover]); the library grid wraps it with selection, a
/// context menu and the extra chips (see RomGridItem). Presentational only —
/// every behavior (tap, selection, favorites) belongs to the caller.
///
/// The trophy/strip inks are fixed scrim colors, since they sit on artwork that
/// is full-colour in either palette.
class GameCover extends StatelessWidget {
  final RomResult rom;

  /// The line(s) under the title. Home passes its console read; the grid passes
  /// the achievement numbers + chips and a status/size line.
  final Widget meta;

  /// Art box height. Null makes the art fill the available height (Expanded),
  /// for a fixed-height grid cell; Home passes a square height.
  final double? height;

  /// Outer width. Null fills the parent (grid cell); Home passes a square.
  final double? width;

  /// Filename line between the title and [meta] (grid, play mode).
  final String? fileName;

  /// Overlays pinned to the art's top-left (grid disc/dup badges).
  final List<Widget> artOverlays;

  /// Top-right art overlay that stands in for the mastery trophy (grid
  /// selection dot). Null keeps the trophy on a mastered set.
  final Widget? corner;

  /// Title/filename ink override (grid favorite rows flip to white).
  final Color? foreground;

  /// Draw the hairline around the art and round its corners. Home (a bare tile)
  /// yes; the grid, whose UiCard already draws the border and clips, no.
  final bool framedArt;

  /// Inset for the text block under the art.
  final EdgeInsets textPadding;

  const GameCover({
    super.key,
    required this.rom,
    required this.meta,
    this.height,
    this.width,
    this.fileName,
    this.artOverlays = const [],
    this.corner,
    this.foreground,
    this.framedArt = true,
    this.textPadding = const EdgeInsets.only(top: 8),
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final title = listingTitle(rom.gameTitle, rom.fileName);
    final art = _art(ui);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (height != null)
            SizedBox(height: height, child: art)
          else
            Expanded(child: art),
          Padding(
            padding: textPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: foreground)),
                if (fileName != null)
                  Text(fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10, color: foreground ?? ui.muted)),
                const SizedBox(height: 3),
                meta,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _art(UiTokens ui) {
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final mastered = total > 0 && earned >= total;
    final inProgress = total > 0 && earned > 0 && !mastered;

    final thumb = RomThumb(rom: rom, size: null, raArt: rom.thumbArt ?? rom.boxArt);
    final stack = Stack(
      fit: StackFit.expand,
      children: [
        framedArt
            ? DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: Border.all(color: ui.border, width: ui.borderWidth),
                  borderRadius: ui.roundMd,
                ),
                child: thumb,
              )
            : thumb,
        if (artOverlays.isNotEmpty)
          Positioned(
            top: 6,
            left: 6,
            child: Wrap(spacing: 4, runSpacing: 4, children: artOverlays),
          ),
        if (corner != null)
          Positioned(top: 6, right: 6, child: corner!)
        else if (mastered)
          Positioned(top: 8, right: 8, child: _trophy(ui)),
        if (inProgress) _strip(ui, earned / total),
      ],
    );
    // A bare Home tile rounds its own corners; in the card the tile's UiCard
    // already clips, so a second rounding would leave a sliver at the top.
    return framedArt ? ClipRRect(borderRadius: ui.roundMd, child: stack) : stack;
  }

  Widget _trophy(UiTokens ui) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: ui.accentGames,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(Icons.emoji_events, size: 17, color: ui.background),
      );

  Widget _strip(UiTokens ui, double frac) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 18, 10, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                // 0.88, not 0.80: kScrim is tinted, so matching the weight of
                // the pure black this replaced needs the extra alpha.
                kScrim.withValues(alpha: 0.88),
                kScrim.withValues(alpha: 0),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: UiTokens.pill,
                  child: SizedBox(
                    height: 5,
                    child: Stack(children: [
                      ColoredBox(color: kOnScrim.withValues(alpha: 0.33)),
                      FractionallySizedBox(
                        widthFactor: frac.clamp(0.0, 1.0),
                        child: const ColoredBox(color: kOnScrimAccent),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(frac * 100).round()}%',
                  style: ui.mono.copyWith(fontSize: 10, color: kOnScrim)),
            ],
          ),
        ),
      );
}

/// The achievement read shared by every game tile: `earned/total` in the
/// standard mono/olive, then the caller's [trailing] widgets (Home: nothing
/// extra; the grid: its chips) on the same single, clipped line. The numbers
/// are dropped when the set has none, so an unmatched tile shows just its chips.
class GameMetaRow extends StatelessWidget {
  final RomResult rom;
  final List<Widget> trailing;

  /// Overrides the numbers' colour (grid favorite rows flip to white).
  final Color? numberColor;

  const GameMetaRow({
    super.key,
    required this.rom,
    this.trailing = const [],
    this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final items = <Widget>[
      if (total > 0)
        Text('$earned/$total',
            style: ui.mono
                .copyWith(fontSize: 11, color: numberColor ?? ui.accentGames)),
      ...trailing,
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    // Height-capped and hard-clipped: a fixed grid cell can't grow, so a long
    // chip run stays on one line and the overflow is cut rather than wrapping
    // the tile past its cell.
    return SizedBox(
      height: 20,
      child: Wrap(
        clipBehavior: Clip.hardEdge,
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      ),
    );
  }
}
