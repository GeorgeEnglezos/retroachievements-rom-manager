import 'package:flutter/widgets.dart' show VoidCallback;
import '../services/play_view.dart' show listingTitle;
import '../services/storage_treemap.dart' show TreemapItem;
import 'folder_stats.dart' show formatBytes;
import 'rom_result.dart';

/// View-model for one listing row; every renderable field optional so
/// non-ROM screens reuse the same tile. [rom] backs actions that need it.
class RomRow {
  final String title;
  final String? subtitle;
  final String? filePath;
  final RomStatus? status;
  final String? imageIcon;
  final int? sizeBytes;
  final double? sizeFraction;
  final int? earnedAchievements;
  final int? totalAchievements;
  final VoidCallback? onTap;
  final bool showChevron;
  final RomResult? rom;
  // >1 when this row collapses a multi-disc set; drives the disc badge and the
  // grid's group-open behavior.
  final int? discCount;
  // Every file this row represents (all discs of the set). Null for single
  // files. Group-wide delete/exclude act on these instead of just [filePath].
  final List<String>? groupPaths;
  // Small trailing metric (e.g. the least-played score), shown right of the title.
  final String? scoreLabel;

  const RomRow({
    required this.title,
    this.subtitle,
    this.filePath,
    this.status,
    this.imageIcon,
    this.sizeBytes,
    this.sizeFraction,
    this.earnedAchievements,
    this.totalAchievements,
    this.onTap,
    this.showChevron = false,
    this.rom,
    this.discCount,
    this.groupPaths,
    this.scoreLabel,
  });

  String? get sizeLabel => sizeBytes == null ? null : formatBytes(sizeBytes!);

  factory RomRow.fromRom(RomResult rom,
          {VoidCallback? onTap, String? scoreLabel}) =>
      RomRow(
        title: listingTitle(rom.gameTitle, rom.fileName),
        subtitle: rom.fileName,
        filePath: rom.filePath,
        status: rom.status,
        imageIcon: rom.thumbArt,
        sizeBytes: rom.fileSize,
        earnedAchievements: rom.earnedAchievements,
        totalAchievements: rom.achievementCount, // RomResult.achievementCount is the total
        onTap: onTap,
        rom: rom,
        scoreLabel: scoreLabel,
      );

  factory RomRow.fromTreemap(TreemapItem item,
          {required double fraction,
          required bool isFolder,
          VoidCallback? onTap}) =>
      RomRow(
        title: item.label,
        filePath: isFolder ? null : item.path,
        sizeBytes: item.bytes,
        sizeFraction: fraction,
        showChevron: isFolder,
        onTap: onTap,
      );
}
