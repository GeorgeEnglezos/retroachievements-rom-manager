import '../../models/game_metadata.dart';

/// One source of game metadata for consoles RA doesn't support.
///
/// Providers are UI-free and take their `http.Client` via constructor injection
/// so the network path is testable. Each provider owns its own platform-id
/// table internally.
abstract class MetadataProvider {
  /// Stable id persisted alongside results: 'ra', 'screenscraper', 'igdb'.
  String get id;

  /// Human label for Settings ("RetroAchievements", "ScreenScraper", …).
  String get label;

  /// True if this provider can answer for the given RA console id.
  bool supports(int consoleId);

  /// Look up one game by cleaned name + RA console id.
  /// Returns null when nothing matched. Throws on transport failure.
  Future<GameMetadata?> lookup({
    required String name,
    required int consoleId,
  });
}
