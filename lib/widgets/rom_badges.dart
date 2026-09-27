import 'package:flutter/material.dart';

import '../strings.dart';

import '../models/rom_result.dart';
import '../models/rom_tags.dart';
import '../services/app_mode.dart';
import '../services/hotness.dart';
import '../services/play_view.dart';
import '../services/switch_grouping.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_badge.dart';
import 'rom_tag_badge.dart';

/// Badge/chip builders shared by [RomRowTile] and [RomGridItem] so the rules
/// (labels, colors, tooltips, thresholds) cannot drift between the list and
/// grid views. Builders return null when the badge does not apply.
///
/// Each also honours the play-mode listing settings ([playView]), which read as
/// all-on while cleaning, so the two views stay in step there too.

Widget romBadge(String text, Color color, {String? tooltip, IconData? icon}) {
  final chip = UiBadge(label: text, color: color, icon: icon);
  return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
}

/// "DUP": another copy of this game exists in the folder. Never shown in play
/// mode, which hides every action that could resolve a duplicate anyway.
Widget? dupBadge(RomResult rom, UiTokens ui) =>
    rom.duplicateGroupId == null || gamingMode
    ? null
    : romBadge(
        GameStrings.dupBadge,
        ui.text,
        tooltip: GameStrings.dupTooltip,
        icon: Icons.content_copy,
      );

/// "HOT": the game's RA set has a large active player base.
Widget? hotBadge(RomResult rom) => !isHotGame(rom) || !playView.hot
    ? null
    : romBadge(
        GameStrings.hotBadge,
        Colors.deepOrange,
        tooltip: GameStrings.hotTooltip(rom.numPlayersCasual),
        icon: Icons.local_fire_department,
      );

/// "NO ACH": the game has no achievements: either its hash matched nothing on
/// RA, or the whole console isn't on RA (localOnly / metadataOnly).
Widget? noAchBadge(RomResult rom) {
  if (!playView.noAchievements) return null;
  final tooltip = switch (rom.status) {
    RomStatus.unsupported => GameStrings.noAchGameTooltip,
    RomStatus.localOnly ||
    RomStatus.metadataOnly => GameStrings.noAchConsoleTooltip,
    _ => null,
  };
  return tooltip == null
      ? null
      : romBadge(GameStrings.noAchBadge, kDangerColor, tooltip: tooltip);
}

/// "N ACH": the game's achievement count.
Widget? achBadge(RomResult rom, UiTokens ui) =>
    rom.achievementCount == null || !playView.achievementCount
    ? null
    : UiBadge(
        label: GameStrings.achBadge(rom.achievementCount!),
        color: ui.accentGames,
      );

/// "disks: N": this listing collapses N discs of a multi-disc game. For a
/// Switch title the N files are its base, updates and DLC, not discs, so it
/// reads as a file count instead. [fileName] is the collapsed row's
/// representative file.
Widget? discBadge(int? count, UiTokens ui, {String? fileName}) {
  if (count == null || count < 2) return null;
  if (fileName != null && isSwitchFile(fileName)) {
    return romBadge(
      GameStrings.switchFilesBadge(count),
      ui.accent,
      tooltip: GameStrings.switchFilesTooltip(count),
    );
  }
  return romBadge(
    GameStrings.discsBadge(count),
    ui.accent,
    tooltip: GameStrings.discsTooltip(count),
    icon: Icons.album,
  );
}

/// Filename-derived tag chips (region, HACK, ENG, …).
List<Widget> tagBadges(String fileName) => playView.fileTags
    ? [for (final tag in romTags(fileName)) RomTagBadge(tag: tag)]
    : const [];
