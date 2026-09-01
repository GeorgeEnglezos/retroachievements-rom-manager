import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../models/rom_tags.dart';
import '../services/app_mode.dart';
import '../services/hotness.dart';
import '../services/play_view.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_badge.dart';
import 'rom_tag_badge.dart';

/// Badge/chip builders shared by [RomRowTile] and [RomGridItem] so the rules
/// (labels, colors, tooltips, thresholds) cannot drift between the list and
/// grid views. Builders return null when the badge does not apply.
///
/// Each also honours the play-mode listing settings ([playView]), which read as
/// all-on while cleaning, so the two views stay in step there too.

Widget romBadge(String text, Color color, {String? tooltip}) {
  final chip = UiBadge(label: text, color: color);
  return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
}

/// "⧉ DUP": another copy of this game exists in the folder. Never shown in play
/// mode, which hides every action that could resolve a duplicate anyway.
Widget? dupBadge(RomResult rom, UiTokens ui) =>
    rom.duplicateGroupId == null || gamingMode
        ? null
        : romBadge('⧉ DUP', ui.text,
            tooltip: 'Another copy of this game is in this folder.');

/// "🔥 HOT": the game's RA set has a large active player base.
Widget? hotBadge(RomResult rom) => !isHotGame(rom) || !playView.hot
    ? null
    : romBadge('🔥 HOT', Colors.deepOrange,
        tooltip: 'Hot on RetroAchievements: '
            '${rom.numPlayersCasual} players have earned achievements in this set '
            '(≥ $hotPlayerThreshold).');

/// "NO ACH": the game has no achievements: either its hash matched nothing on
/// RA, or the whole console isn't on RA (localOnly / metadataOnly).
Widget? noAchBadge(RomResult rom) {
  if (!playView.noAchievements) return null;
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
Widget? achBadge(RomResult rom, UiTokens ui) =>
    rom.achievementCount == null || !playView.achievementCount
        ? null
        : UiBadge(label: '${rom.achievementCount} ACH', color: ui.accentGames);

/// "💿 N": this listing collapses N discs of a multi-disc game.
Widget? discBadge(int? count, UiTokens ui) => (count == null || count < 2)
    ? null
    : romBadge('💿 $count', ui.accent, tooltip: '$count-disc game');

/// Filename-derived tag chips (region, HACK, ENG, …).
List<Widget> tagBadges(String fileName) => playView.fileTags
    ? [for (final tag in romTags(fileName)) RomTagBadge(tag: tag)]
    : const [];
