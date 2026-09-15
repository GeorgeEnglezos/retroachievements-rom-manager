import 'package:flutter/material.dart';
import '../models/folder_stats.dart' show achievementFraction, kNearMasteryRatio;
import '../models/rom_result.dart';
import '../services/ra_service.dart' show RaAward;
import '../theme/ui_tokens.dart';
import 'ui/ui_progress_bar.dart';

/// Achievement progress bar + label, shared by tiles and the detail dialog.
/// Only meaningful when [hasProgress] is true.
class RomProgress extends StatelessWidget {
  final RomResult rom;
  final double barHeight;
  final double labelSize;
  final FontWeight labelWeight;

  /// Puts the label beside the bar instead of under it, so a list row spends
  /// one line on progress rather than two.
  final bool inline;

  /// Overrides the award-derived bar/label colour. Favorite rows pass
  /// ui.favoriteInk so the bar reads against the favorite fill like the row's
  /// other labels, instead of an award hue that clashes with it.
  final Color? colorOverride;

  const RomProgress({
    super.key,
    required this.rom,
    this.barHeight = 6,
    this.labelSize = 9,
    this.labelWeight = FontWeight.w500,
    this.inline = false,
    this.colorOverride,
  });

  /// True when the ROM has a known achievement total to show progress against.
  static bool hasProgress(RomResult rom) {
    final total = rom.achievementCount;
    return rom.earnedAchievements != null && total != null && total > 0;
  }

  /// A short, actionable mastery line, or null when there's nothing useful to
  /// say (no progress data, or set not started). Turns the bar into a decision
  /// surface: how close mastery is and how many are left.
  static String? masteryHint(RomResult rom) {
    if (!hasProgress(rom)) return null;
    final earned = rom.earnedAchievements!;
    final total = rom.achievementCount!;
    if (earned >= total) {
      // RA "completed" is all-achievements softcore, distinct from a hardcore
      // mastery; don't call it mastered.
      return rom.highestAward == RaAward.completed
          ? "You've completed this set (softcore) ✓"
          : "You've mastered this set ★";
    }
    if (earned == 0) return null;
    final remaining = total - earned;
    final plural = remaining == 1 ? '' : 's';
    if (achievementFraction(earned, total) >= kNearMasteryRatio) {
      return '🏆 Close to mastery: $remaining achievement$plural to go';
    }
    return '$remaining achievement$plural to go';
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final earned = rom.earnedAchievements ?? 0;
    final total = rom.achievementCount ?? 0;
    final fraction = achievementFraction(earned, total);

    // The RA award is authoritative when present: it distinguishes a hardcore
    // mastery from a softcore completion, and marks "beaten" (game finished but
    // not every achievement earned). Falls back to the count when absent.
    final String label;
    final Color color;
    switch (rom.highestAward ?? RaAward.none) {
      case RaAward.mastered:
        label = 'Mastered ★';
        color = ui.warning;
      case RaAward.completed:
        label = 'Completed ✓';
        color = ui.warning;
      case RaAward.beatenHardcore || RaAward.beatenSoftcore:
        label = 'Beaten';
        color = ui.accentGames;
      case RaAward.none:
        if (total > 0 && earned >= total) {
          label = 'Mastered ★';
          color = ui.warning;
        } else if (earned == 0) {
          label = 'Not started';
          color = ui.muted;
        } else {
          label = '$earned / $total';
          color = ui.supported;
        }
    }

    final barColor = colorOverride ?? color;
    final bar = UiProgressBar(
      value: fraction,
      height: barHeight,
      color: barColor,
      // On a favorite fill the palette trough vanishes; a faint wash of the ink
      // keeps the track visible.
      trough: colorOverride?.withValues(alpha: 0.25),
    );
    final text = Text(label,
        style: TextStyle(
            fontSize: labelSize, color: barColor, fontWeight: labelWeight));

    if (inline) {
      return Row(
        children: [
          Expanded(child: bar),
          const SizedBox(width: 10),
          text,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: double.infinity, child: bar),
        const SizedBox(height: 3),
        text,
      ],
    );
  }
}
