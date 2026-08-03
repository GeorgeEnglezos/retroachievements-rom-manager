import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../models/rom_tags.dart';
import '../services/hotness.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_badge.dart';
import 'rom_tag_badge.dart';

/// Badge/chip builders shared by [RomRowTile] and [RomGridItem] so the rules
/// (labels, colors, tooltips, thresholds) cannot drift between the list and
/// grid views. Builders return null when the badge does not apply.

Widget romBadge(String text, Color color, {String? tooltip}) {
  final chip = UiBadge(label: text, color: color);
  return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
}

/// "⧉ DUP": another copy of this game exists in the folder.
Widget? dupBadge(RomResult rom, UiTokens ui) => rom.duplicateGroupId == null
    ? null
    : romBadge('⧉ DUP', ui.text,
        tooltip: 'Another copy of this game is in this folder.');

/// "🔥 HOT": the game's RA set has a large active player base.
Widget? hotBadge(RomResult rom) => !isHotGame(rom)
    ? null
    : romBadge('🔥 HOT', Colors.deepOrange,
        tooltip: 'Hot on RetroAchievements: '
            '${rom.numPlayersCasual} players have earned achievements in this set '
            '(≥ $hotPlayerThreshold).');

/// "NO ACH": the game has no achievements: either its hash matched nothing on
/// RA, or the whole console isn't on RA (localOnly / metadataOnly).
Widget? noAchBadge(RomResult rom) {
  final tooltip = switch (rom.status) {
    RomStatus.unsupported =>
      'No achievements on RetroAchievements for this game.',
    RomStatus.localOnly ||
    RomStatus.metadataOnly =>
      'This console is not on RetroAchievements.',
    _ => null,
  };
  return tooltip == null ? null : romBadge('NO ACH', kDangerColor, tooltip: tooltip);
}

/// "N ACH": the game's achievement count.
Widget? achBadge(RomResult rom, UiTokens ui) => rom.achievementCount == null
    ? null
    : UiBadge(label: '${rom.achievementCount} ACH', color: ui.accentGames);

/// "💿 N": this listing collapses N discs of a multi-disc game.
Widget? discBadge(int? count, UiTokens ui) => (count == null || count < 2)
    ? null
    : romBadge('💿 $count', ui.accent, tooltip: '$count-disc game');

/// Filename-derived tag chips (region, HACK, ENG, …).
List<Widget> tagBadges(String fileName) =>
    [for (final tag in romTags(fileName)) RomTagBadge(tag: tag)];
