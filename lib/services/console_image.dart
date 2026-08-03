/// Console id -> bundled picture asset; widget layer handles missing files.
class ConsoleImage {
  ConsoleImage._();

  /// Display-only (non-RA) console ids -> logo filename under
  /// `assets/consoles/unsupported/`. See [ConsoleMap.displayNames].
  static const Map<int, String> _unsupportedAsset = {
    -1: 'switch',
    -2: 'wiiu',
    -3: 'ps3',
    -4: 'ps4',
    -5: 'vita',
    -6: 'xbox',
    -7: 'xbox360',
  };

  /// Fallback logo for a folder whose system we can't identify at all.
  static const String genericAsset = 'assets/consoles/unsupported/generic.png';

  /// Console ids whose logo is light-on-dark (Atari Lynx, Wii, Arcade). Those
  /// vanish on a light surface, so every view that renders them tints the
  /// asset to the theme's ink color instead.
  static const Set<int> tintedLogos = {13, 19, 27};

  /// Asset path for [consoleId], or null when the id is null/unknown.
  static String? assetFor(int? consoleId) {
    if (consoleId == null) return null;
    final key = _unsupportedAsset[consoleId];
    if (key != null) return 'assets/consoles/unsupported/$key.png';
    return 'assets/consoles/$consoleId.png';
  }

  /// Asset path for [consoleId], falling back to the generic logo for
  /// unidentified folders. Never null; use where a logo must always render.
  static String assetOrGeneric(int? consoleId) =>
      assetFor(consoleId) ?? genericAsset;
}
