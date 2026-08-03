import 'package:path/path.dart' as p;

/// GC/Wii disc extensions by hashability: rcheevos reads raw discs only;
/// compressed containers need DiscDecompressor first.
class DiscFormats {
  DiscFormats._();

  /// Raw disc images rcheevos can open as-is.
  static const directlyHashable = {'iso', 'gcm'};

  /// Compressed disc containers rcheevos cannot read; need decompression.
  static const needsDecompressionExts = {'rvz', 'wbfs', 'wia', 'gcz', 'ciso'};

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  /// NKit (`*.nkit.iso`/`.nkit.gcm`): stripped images whose hash RA doesn't
  /// know, and DolphinTool can't rebuild them, so they're flagged unsupported.
  static bool isNkit(String path) {
    final name = p.basename(path).toLowerCase();
    return name.endsWith('.nkit.iso') || name.endsWith('.nkit.gcm');
  }

  /// True when [path] is a compressed disc container rcheevos cannot read and
  /// DolphinTool *can* decompress to a raw iso. Excludes NKit (see [isNkit]).
  static bool needsDecompression(String path) =>
      needsDecompressionExts.contains(_ext(path));
}
