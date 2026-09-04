import 'package:flutter/material.dart';
import '../models/folder_stats.dart' show compactCount;
import '../models/rom_result.dart';
import '../services/play_view.dart';
import '../theme/ui_tokens.dart';
import 'ra_image.dart';
import 'ui/ui_progress_bar.dart';

/// The Home dashboard's featured game: a cinematic banner built from the game's
/// box art, with a mastery readout and a button into its detail. A committed
/// single-look element: text sits on a dark scrim over the art, so it takes
/// the fixed kOnScrim* inks in both themes rather than palette ink, which
/// would be dark-on-dark in the light palette.
class SpotlightHero extends StatelessWidget {
  final RomResult rom;
  final VoidCallback onOpen;

  /// Phone layout: shorter, smaller type, and the scrim runs bottom-to-top so
  /// the art stays visible above the text instead of behind it.
  final bool compact;

  /// Landscape-phone layout: a short side-by-side banner. Keeps the eyebrow,
  /// title, meta and bar but at a fraction of the height, so two heroes and the
  /// shelves below all fit the sideways screen. Wins over [compact] when set.
  final bool mini;

  /// The kicker pill's caption; names why this game is featured.
  final String eyebrow;

  const SpotlightHero({
    super.key,
    required this.rom,
    required this.onOpen,
    this.compact = false,
    this.mini = false,
    this.eyebrow = 'CLOSEST TO MASTERY',
  });

  /// Width of the completion bar. Fixed rather than full-width so it reads as a
  /// readout under the title instead of a divider across the banner.
  static const _barWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final title = listingTitle(rom.gameTitle, rom.fileName);
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final frac = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final art = rom.boxArt;

    // One mono readout under the title: where the game lives, how far in it is
    // and how big its set is. Genre and file size are library detail, not hero
    // material, and the completion percentage rides on the bar below.
    final meta = [
      rom.consoleName,
      if (total > 0) '$earned/$total achievements',
      if ((rom.points ?? 0) > 0) '${rom.points} pts',
      if ((rom.numPlayersCasual ?? 0) > 0)
        '${compactCount(rom.numPlayersCasual!)} players',
    ].whereType<String>().join('  ·  ');

    // One size ladder: mini (landscape) < compact (portrait) < full (wide).
    final titleSize = mini ? 19.0 : (compact ? 28.0 : 42.0);
    final pad = mini ? 14.0 : (compact ? 18.0 : 28.0);
    final minH = mini ? 92.0 : (compact ? 260.0 : 300.0);
    // The bottom-to-top scrim is only for the tall portrait banner; mini goes
    // back to the side scrim so the short card keeps its art on the right.
    final vscrim = compact && !mini;

    return ClipRRect(
      borderRadius: ui.roundLg,
      child: Stack(
        children: [
          Positioned.fill(
            child: art != null
                ? RaImage(url: raImageUrl(art), fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [ui.accent, ui.accentAlt],
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: vscrim
                    ? LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          kScrim.withValues(alpha: 0.96),
                          kScrim.withValues(alpha: 0.80),
                          kScrim.withValues(alpha: 0.20),
                        ],
                        stops: const [0, 0.55, 1],
                      )
                    : LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          kScrim.withValues(alpha: 0.94),
                          kScrim.withValues(alpha: 0.60),
                          kScrim.withValues(alpha: 0.07),
                        ],
                        stops: const [0, 0.5, 0.88],
                      ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Portrait hugs the bottom so the art reads above it; mini and
                  // wide centre in their band.
                  mainAxisAlignment:
                      vscrim ? MainAxisAlignment.end : MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Eyebrow(eyebrow),
                    SizedBox(height: mini ? 7 : 12),
                    Text(title,
                        maxLines: mini ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: ui.display.copyWith(
                            color: kOnScrim, fontSize: titleSize, height: 0.98)),
                    if (meta.isNotEmpty) ...[
                      SizedBox(height: mini ? 6 : 12),
                      Text(meta,
                          maxLines: mini ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: ui.mono.copyWith(
                              color: kOnScrimMuted,
                              fontSize: mini ? 10 : 11,
                              fontWeight: FontWeight.w500)),
                    ],
                    if (total > 0) ...[
                      SizedBox(height: mini ? 8 : (compact ? 14 : 18)),
                      _bar(frac, mini ? 150 : _barWidth),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onOpen,
                child: Semantics(button: true, label: 'View $title'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The mockup's "loading" bar: the fill sweeps in from the left on mount
  // (UiProgressBar's easeOutBack tween) rather than drawing at its final width.
  // Scrim inks, since it sits on the artwork.
  Widget _bar(double frac, double width) => SizedBox(
        width: width,
        child: UiProgressBar(
          value: frac,
          height: 7,
          color: kOnScrimAccent,
          trough: kOnScrim.withValues(alpha: 0.25),
        ),
      );
}

/// The banner's kicker: an outlined pill rather than bare caps, so the label
/// keeps its own shape against whatever artwork sits behind it.
class _Eyebrow extends StatelessWidget {
  final String label;
  const _Eyebrow(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kOnScrim.withValues(alpha: 0.14),
          borderRadius: UiTokens.pill,
          border: Border.all(color: kOnScrim.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: context.ui.labelCaps
                .copyWith(color: kOnScrimAccent, fontSize: 10, letterSpacing: 2)),
      );
}
