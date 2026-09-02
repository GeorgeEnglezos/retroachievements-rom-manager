import 'package:path/path.dart' as p;

/// GC/Wii disc extensions by hashability: rcheevos reads raw discs only;
/// compressed containers need DiscDecompressor first.
class DiscFormats {
  DiscFormats._();

  /// Compressed containers we attempt to decompress on the fly in Dart (see
  /// `disc_reader`), so they hash without DolphinTool. RVZ is an attempt: the
  /// reader handles GameCube RVZ but declines Wii RVZ (falls back to DolphinTool).
  static const onDeviceReaderExts = {'ciso', 'wbfs', 'gcz', 'rvz'};

  /// Containers DolphinTool can decompress, used as the fallback when the
  /// on-device reader declines (Wii RVZ) or for formats with no reader (WIA).
  static const needsDolphinToolExts = {'rvz', 'wia'};

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  /// NKit (`*.nkit.iso`/`.nkit.gcm`): stripped images whose hash RA doesn't
  /// know, and DolphinTool can't rebuild them, so they're flagged unsupported.
  static bool isNkit(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('.nkit.iso') || name.endsWith('.nkit.gcm');
  }

  /// True when [path] can be decompressed on the fly in Dart and hashed on any
  /// platform (no DolphinTool). See `disc_reader.openDiscReader`.
  static bool hasOnDeviceReader(String path) =>
      onDeviceReaderExts.contains(_ext(path));

  /// True when [path] still requires DolphinTool (desktop only) to hash.
  static bool needsDolphinTool(String path) =>
      needsDolphinToolExts.contains(_ext(path));

  /// True when [path] can only be hashed via DolphinTool (no on-device reader
  /// attempt at all), so without it the file is unhashable. WIA today; RVZ is
  /// excluded because GameCube RVZ hashes on-device.
  static bool requiresDolphinTool(String path) =>
      needsDolphinTool(path) && !hasOnDeviceReader(path);
}
