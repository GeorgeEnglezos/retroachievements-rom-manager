import 'package:flutter/material.dart';
import '../models/rom_result.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_progress_bar.dart';

/// Achievement progress bar + label, shared by tiles and the detail dialog.
/// Only meaningful when [hasProgress] is true.
class RomProgress extends StatelessWidget {
  final RomResult rom;
  final double barHeight;
  final double labelSize;
  final FontWeight labelWeight;

  const RomProgress({
    super.key,
    required this.rom,
    this.barHeight = 6,
    this.labelSize = 9,
    this.labelWeight = FontWeight.w500,
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
    if (earned >= total) return "You've mastered this set ★";
    if (earned == 0) return null;
    final remaining = total - earned;
    final plural = remaining == 1 ? '' : 's';
    if (earned / total >= 0.8) {
      return '🏆 Close to mastery: $remaining achievement$plural to go';
    }
    return '$remaining achievement$plural to go';
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final earned = rom.earnedAchievements ?? 0;
    final total = rom.achievementCount ?? 0;
    final fraction = total == 0 ? 0.0 : earned / total;
    final mastered = total > 0 && earned >= total;
    final label = mastered
        ? 'Mastered ★'
        : earned == 0
            ? 'Not started'
            : '$earned / $total';
    final color = mastered
        ? ui.warning
        : earned == 0
            ? ui.muted
            : ui.supported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: UiProgressBar(value: fraction, height: barHeight),
        ),
        const SizedBox(height: 3),
        Text(label,
            style:
                TextStyle(fontSize: labelSize, color: color, fontWeight: labelWeight)),
      ],
    );
  }
}
