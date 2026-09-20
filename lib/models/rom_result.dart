import '../services/ra_service.dart' show RaAward;
import 'folder_stats.dart' show formatBytes;
import 'game_metadata.dart';

enum RomStatus {
  notFetched,
  checking,
  supported,
  unsupported,
  unsupportedFormat,
  error,
  // Console isn't on RetroAchievements (or the folder is unidentified), local
  // library info only, never hashed or fetched. See ConsoleMap.isRaSupported.
  localOnly,
  // Display-only console enriched with third-party game metadata (title, cover,
  // publisher…) but no achievements. See GameMetadata / applyMetadata.
  metadataOnly,
}


/// The one wording for each status. Every surface that names a status (filter
/// chip, row subtitle, grid cell) reads it from here, so the same state isn't
/// worded three ways; the switch is exhaustive so a new status has to be named
/// rather than falling through a default. Listings suppress the states that
/// need no note and the row tile overrides [RomStatus.unsupportedFormat] with
/// its longer, format-specific hint.
String statusLabel(RomStatus s) => switch (s) {
      RomStatus.notFetched => 'Not fetched',
      RomStatus.checking => 'Checking...',
      RomStatus.supported => 'Supported',
      RomStatus.unsupported => 'No achievements',
      RomStatus.unsupportedFormat => 'Bad format',
      RomStatus.error => 'Error',
      RomStatus.localOnly => 'Not on RetroAchievements',
      RomStatus.metadataOnly => 'No achievements',
    };

// RA returns a placeholder title like "GAME #1100002368" for matched games that
// have no real name yet (and folder_view falls back to "Game #<id>" on a failed
// detail fetch). In those cases the original file name is more useful.
final _placeholderTitle = RegExp(r'^game\s*#\s*\d+$', caseSensitive: false);

String gameDisplayName(String? title, String fileName) {
  final t = title?.trim();
  if (t == null || t.isEmpty || _placeholderTitle.hasMatch(t)) return fileName;
  return t;
}

class RomResult {
  final String filePath;
  final String fileName;
  RomStatus status;
  String? md5Hash;
  // RA console id [md5Hash] was computed under (disc hashes are console-specific;
  // a changed folder->console mapping invalidates an old hash). See GameEntry.
  int? hashConsoleId;
  int? consoleId;
  int? gameId;
  String? gameTitle;
  String? consoleName;
  int? achievementCount;
  String? imageIcon;
  String? imageBoxArt;
  String? imageTitle; // RA title-screen screenshot path
  String? imageIngame; // RA in-game screenshot path
  // Absolute cover URL from a third-party provider (metadataOnly rows). The
  // image widget renders an http(s) url as-is vs an RA path via the host prefix.
  String? imageUrl;
  // True when a third-party name match scored below kLowConfidenceThreshold.
  bool lowConfidenceMatch = false;
  // The third-party match itself (metadataOnly rows), kept so it persists to
  // GameEntry.metadata unchanged.
  GameMetadata? metadata;
  String? publisher;
  String? developer;
  String? genre;
  String? released;
  DateTime? setCreated;
  DateTime? setUpdated;
  int? points;
  int? numPlayersCasual;
  int? numPlayersHardcore;
  int? earnedAchievements;
  int? earnedHardcore;
  // Highest RA award (beaten/completed/mastered); null until progress loads.
  RaAward? highestAward;
  DateTime? highestAwardDate;
  DateTime? lastPlayed;
  String? errorMessage;

  // Non-null when this ROM shares a duplicate group with others in its folder.
  int? duplicateGroupId;

  int? fileSize;

  String? get fileSizeLabel {
    final s = fileSize;
    return s == null ? null : formatBytes(s);
  }

  bool get isLocalOnly => status == RomStatus.localOnly;

  // Thumbnail art: a third-party cover url when present, else the RA icon path.
  // raImageUrl() renders an absolute url as-is and an RA path via the host.
  String? get thumbArt => imageUrl ?? imageIcon;
  // Larger art for the detail view: third-party cover else RA box art.
  String? get boxArt => imageUrl ?? imageBoxArt;
  // Home's featured banners: an actual gameplay screenshot reads truer than
  // box art at that size, so prefer the in-game shot, then the title screen,
  // then fall back to boxArt (a third-party cover has neither).
  String? get heroArt => imageIngame ?? imageTitle ?? boxArt;

  RomResult({required this.filePath, required this.fileName})
      : status = RomStatus.notFetched;
}
