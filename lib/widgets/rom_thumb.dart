import 'dart:io';

import 'package:flutter/material.dart';

import '../models/rom_result.dart';
import '../theme/ui_tokens.dart';
import '../services/scraper/scraped_store.dart';
import 'ra_image.dart';
import 'rom_actions.dart';

/// The listing thumbnail: RA art when the ROM is matched, else imported
/// (Skraper) box art from disk, else the ROM's status icon. Shared so every
/// listing falls back the same way.
class RomThumb extends StatelessWidget {
  final RomResult rom;

  /// Side of the square thumbnail. Null fills whatever box the parent gives it
  /// (the grid tile's full-bleed art slot), which then owns the clipping.
  final double? size;

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
        borderRadius: size == null ? null : context.ui.roundMd,
        error: _fallback(context),
        placeholder: SizedBox(
          width: size,
          height: size,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    // In-memory map lookup (no I/O): the store is loaded once at startup.
    final scrapedArt = ScrapedStore.instance.get(rom.filePath)?.thumbPath;
    if (scrapedArt == null) return _fallback(context);
    final image = Image.file(
      File(scrapedArt),
      width: size,
      height: size,
      // Decode at thumbnail size: scraper PNGs are full covers and would
      // otherwise fill the image cache at native resolution per row.
      cacheWidth: ((size ?? 300) * 2).round(),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(context),
    );
    if (size == null) return image;
    return ClipRRect(borderRadius: context.ui.roundMd, child: image);
  }

  /// The status icon. Full-bleed callers get it on a filled panel, since a bare
  /// icon on a transparent box would leave a hole in the tile.
  Widget _fallback(BuildContext context) {
    final icon = romStatusIcon(rom);
    if (size != null) return icon;
    return ColoredBox(
        color: context.ui.surfaceAlt, child: Center(child: icon));
  }
}
