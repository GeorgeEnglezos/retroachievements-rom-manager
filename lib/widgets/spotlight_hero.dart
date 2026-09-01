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

  /// The kicker pill's caption; names why this game is featured.
  final String eyebrow;

  const SpotlightHero({
    super.key,
    required this.rom,
    required this.onOpen,
    this.compact = false,
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
                gradient: compact
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
            constraints: BoxConstraints(minHeight: compact ? 260 : 300),
            child: Padding(
              padding: EdgeInsets.all(compact ? 18 : 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // Text hugs the bottom so the art reads above it.
                  mainAxisAlignment:
                      compact ? MainAxisAlignment.end : MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Eyebrow(eyebrow),
                    const SizedBox(height: 12),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ui.display.copyWith(
                            color: kOnScrim,
                            fontSize: compact ? 28 : 42,
                            height: 0.98)),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ui.mono.copyWith(
                              color: kOnScrimMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                    if (total > 0) ...[
                      SizedBox(height: compact ? 14 : 18),
                      _bar(frac),
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
  Widget _bar(double frac) => SizedBox(
        width: _barWidth,
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
