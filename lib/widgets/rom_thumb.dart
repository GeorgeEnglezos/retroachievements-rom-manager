import 'dart:io';

import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../services/scraper/scraped_store.dart';
import 'ra_image.dart';
import 'rom_actions.dart';

/// The listing thumbnail: RA art when the ROM is matched, else imported
/// (Skraper) box art from disk, else the ROM's status icon. Shared so every
/// listing falls back the same way.
class RomThumb extends StatelessWidget {
  final RomResult rom;
  final double size;

  /// RA image path to show when the ROM is matched. Callers pick which one:
  /// the row listing shows the icon, the grid its larger thumb.
  final String? raArt;

  const RomThumb({
    super.key,
    required this.rom,
    required this.size,
    this.raArt,
  });

  @override
  Widget build(BuildContext context) {
    final matched = rom.status == RomStatus.supported ||
        rom.status == RomStatus.metadataOnly;
    if (matched && raArt != null) {
      return RaImage(
        url: raImageUrl(raArt!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(4),
        error: romStatusIcon(rom),
        placeholder: SizedBox(
          width: size,
          height: size,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    // In-memory map lookup (no I/O): the store is loaded once at startup.
    final scrapedArt = ScrapedStore.instance.get(rom.filePath)?.thumbPath;
    if (scrapedArt == null) return romStatusIcon(rom);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(scrapedArt),
        width: size,
        height: size,
        // Decode at thumbnail size: scraper PNGs are full covers and would
        // otherwise fill the image cache at native resolution per row.
        cacheWidth: (size * 2).round(),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => romStatusIcon(rom),
      ),
    );
  }
}
