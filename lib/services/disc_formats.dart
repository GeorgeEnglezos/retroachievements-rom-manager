import 'package:path/path.dart' as p;

/// GC/Wii disc extensions by hashability: rcheevos reads raw discs only;
/// compressed containers need DiscDecompressor first.
class DiscFormats {
  DiscFormats._();

  /// Raw disc images rcheevos can open as-is.
  static const directlyHashable = {'iso', 'gcm'};

  /// Compressed containers we decompress on the fly in Dart (see `disc_reader`),
  /// so they hash on any platform without DolphinTool.
  static const onDeviceReaderExts = {'ciso', 'wbfs', 'gcz'};

  /// Compressed containers that still need DolphinTool (desktop only): their
  /// per-block codecs aren't implemented on-device yet.
  static const needsDolphinToolExts = {'rvz', 'wia'};

  /// Compressed disc containers rcheevos cannot read directly (either path).
  static const needsDecompressionExts = {
    ...onDeviceReaderExts,
    ...needsDolphinToolExts,
  };

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  /// NKit (`*.nkit.iso`/`.nkit.gcm`): stripped images whose hash RA doesn't
  /// know, and DolphinTool can't rebuild them, so they're flagged unsupported.
  static bool isNkit(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('.nkit.iso') || name.endsWith('.nkit.gcm');
  }

  /// True when [path] is a compressed disc container rcheevos cannot read
  /// directly (either decompression path). Excludes NKit (see [isNkit]).
  static bool needsDecompression(String path) =>
      needsDecompressionExts.contains(_ext(path));

  /// True when [path] can be decompressed on the fly in Dart and hashed on any
  /// platform (no DolphinTool). See `disc_reader.openDiscReader`.
  static bool hasOnDeviceReader(String path) =>
      onDeviceReaderExts.contains(_ext(path));

  /// True when [path] still requires DolphinTool (desktop only) to hash.
  static bool needsDolphinTool(String path) =>
      needsDolphinToolExts.contains(_ext(path));
}
