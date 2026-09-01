import 'package:flutter/material.dart';
import '../models/rom_result.dart';
import '../theme/ui_tokens.dart';
import 'game_cover.dart';

/// Home's lean game tile: a [GameCover] whose meta line is the achievement
/// numbers and the console name. No context menu or selection — the library
/// grid owns the full-featured tile. Sized to a square by the caller.
class DashboardCover extends StatelessWidget {
  final RomResult rom;
  final VoidCallback onTap;

  /// Height of the art box.
  final double height;

  /// Fixed outer width; the caller lays these out on a grid.
  final double? width;

  const DashboardCover({
    super.key,
    required this.rom,
    required this.onTap,
    this.height = 200,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GameCover(
        rom: rom,
        height: height,
        width: width,
        meta: Row(
          children: [
            Text('$earned/$total',
                style: ui.mono.copyWith(fontSize: 11, color: ui.accentGames)),
            Expanded(
              child: Text('  ·  ${rom.consoleName ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: ui.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
