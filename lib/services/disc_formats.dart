import 'package:path/path.dart' as p;

import 'rom_name.dart';

/// Compressed disc format the Storage advisor recommends. Both still hash here:
/// CHD via libchdr in `raw_hash`, RVZ via `rvz_reader` (zstd-compressed Wii RVZ,
/// Dolphin's default, falls back to DolphinTool).
enum DiscTarget {
  // ponytail: fixed saving ratio per format; real savings vary per game
  // (padding, scrubbing). Sample-compress a file if the estimate needs to be
  // accurate.
  chd(0.4),
  rvz(0.5);

  const DiscTarget(this.savingFraction);
  final double savingFraction;

  /// Rough bytes saved by converting [bytes] of raw images to this format.
  int estimatedSaving(int bytes) => (bytes * savingFraction).round();
}

/// GC/Wii disc extensions by hashability: rcheevos reads raw discs only;
/// compressed containers need DiscDecompressor first.
class DiscFormats {
  DiscFormats._();

  /// Compressed containers we attempt to decompress on the fly in Dart (see
  /// `disc_reader`), so they hash without DolphinTool. RVZ is an attempt: the
  /// reader declines LZMA/bzip2 RVZ and zstd-compressed Wii RVZ (Dolphin's
  /// default), which fall back to DolphinTool.
  static const onDeviceReaderExts = {'ciso', 'wbfs', 'gcz', 'rvz'};

  /// Containers DolphinTool can decompress, used as the fallback when the
  /// on-device reader declines (some RVZ, see above) or for formats with no reader (WIA).
  static const needsDolphinToolExts = {'rvz', 'wia'};

  /// NKit (`*.nkit.iso`/`.nkit.gcm`): stripped images whose hash RA doesn't
  /// know, and DolphinTool can't rebuild them, so they're flagged unsupported.
  static bool isNkit(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('.nkit.iso') || name.endsWith('.nkit.gcm');
  }

  /// True when [path] can be decompressed on the fly in Dart and hashed on any
  /// platform (no DolphinTool). See `disc_reader.openDiscReader`.
  static bool hasOnDeviceReader(String path) =>
      onDeviceReaderExts.contains(bareExtension(path));

  /// True when [path] still requires DolphinTool (desktop only) to hash.
  static bool needsDolphinTool(String path) =>
      needsDolphinToolExts.contains(bareExtension(path));

  /// True when [path] can only be hashed via DolphinTool (no on-device reader
  /// attempt at all), so without it the file is unhashable. WIA today; RVZ is
  /// excluded because GameCube RVZ hashes on-device.
  static bool requiresDolphinTool(String path) =>
      needsDolphinTool(path) && !hasOnDeviceReader(path);

  /// CD/DVD systems (RA console ids) whose raw images can become CHD: Sega CD,
  /// PlayStation, PS2, Saturn, Dreamcast, PSP, 3DO, PC-FX, Neo Geo CD,
  /// PC Engine CD, Jaguar CD.
  static const _chdConsoles = {9, 12, 21, 39, 40, 41, 43, 49, 56, 76, 77};

  /// RA console id for the Wii, whose RVZ only DolphinTool can hash.
  static const wiiConsoleId = 19;

  /// GameCube and Wii.
  static const _rvzConsoles = {16, wiiConsoleId};

  static const _rawCdExts = {'iso', 'bin', 'cue', 'gdi', 'img'};
  static const _sheetExts = {'cue', 'gdi'};
  static const _trackExts = {'bin', 'img'};
  static const _rawGcWiiExts = {'iso', 'gcm', 'wbfs'};

  /// The format worth converting [consoleId]'s raw discs to, or null when the
  /// system has none (cartridges, unknown).
  static DiscTarget? compressTargetFor(int? consoleId) =>
      _chdConsoles.contains(consoleId)
          ? DiscTarget.chd
          : _rvzConsoles.contains(consoleId)
              ? DiscTarget.rvz
              : null;

  /// True when [path] is an uncompressed image that could become [target].
  /// NKit is skipped: RA can't hash it before or after conversion.
  static bool isUncompressedDisc(String path, DiscTarget target) =>
      !isNkit(path) &&
      (target == DiscTarget.chd ? _rawCdExts : _rawGcWiiExts)
          .contains(bareExtension(path));

  /// True for a .cue/.gdi sheet, which stands for its track files.
  static bool isCueSheet(String path) => _sheetExts.contains(bareExtension(path));

  /// True for a raw track (.bin/.img) that a sheet may reference.
  static bool isTrackFile(String path) => _trackExts.contains(bareExtension(path));
}
