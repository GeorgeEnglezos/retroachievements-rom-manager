import 'game_entry.dart';

/// The complete persisted state of one system folder. Serialised to
/// `systems/<systemId>.json`. Self-contained: everything the folder view needs
/// is here, so opening a folder is a single file read.
class SystemData {
  static const int currentVersion = 1;

  /// Stable file key, assigned once (initially `sha1(path)`) and never
  /// recomputed from the path, so renaming the folder does not orphan the file.
  final String systemId;
  final String systemPath;

  /// RA console id for this folder, stored so the home grid can be derived
  /// from memory without an async settings lookup. Null when unmapped.
  final int? consoleId;

  final List<GameEntry> games;
  final Set<String> dismissedDuplicatePairs;

  SystemData({
    required this.systemId,
    required this.systemPath,
    required this.games,
    required this.dismissedDuplicatePairs,
    this.consoleId,
  });

  SystemData copyWith({
    String? systemId,
    String? systemPath,
    int? consoleId,
    List<GameEntry>? games,
    Set<String>? dismissedDuplicatePairs,
  }) =>
      SystemData(
        systemId: systemId ?? this.systemId,
        systemPath: systemPath ?? this.systemPath,
        consoleId: consoleId ?? this.consoleId,
        games: games ?? this.games,
        dismissedDuplicatePairs:
            dismissedDuplicatePairs ?? this.dismissedDuplicatePairs,
      );

  factory SystemData.fromJson(Map<String, dynamic> j) => SystemData(
        systemId: j['systemId'] as String? ?? '',
        systemPath: j['systemPath'] as String,
        consoleId: (j['consoleId'] as num?)?.toInt(),
        games: (j['games'] as List<dynamic>? ?? [])
            .map((e) => GameEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        dismissedDuplicatePairs:
            (j['dismissedDuplicatePairs'] as List<dynamic>? ?? [])
                .cast<String>()
                .toSet(),
      );

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'systemId': systemId,
        'systemPath': systemPath,
        'consoleId': consoleId,
        'games': games.map((g) => g.toJson()).toList(),
        'dismissedDuplicatePairs': dismissedDuplicatePairs.toList(),
      };
}
