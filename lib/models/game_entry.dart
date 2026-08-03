import 'package:path/path.dart' as p;
import '../services/ra_service.dart';
import 'game_metadata.dart';
import 'user_progress.dart';

/// One ROM's complete persisted state: the scan result plus, when matched, the
/// RetroAchievements [GameInfo] and the user's [UserProgress]. Stored inside a
/// system's JSON file (see [SystemData]).
class GameEntry {
  final String filePath;
  final String fileName;
  final int? fileSize;
  final String? md5;
  final int? gameId;
  final bool matched;
  final bool noMatch;
  final DateTime lastScanned;
  final GameInfo? gameInfo;
  final UserProgress? progress;

  /// Third-party game metadata for RA-unsupported (display-only) systems.
  /// Mutually exclusive in practice with [gameInfo] (RA vs third-party console).
  final GameMetadata? metadata;

  /// Console id used for [md5]. A changed folder→console mapping invalidates
  /// the hash; scans re-hash on mismatch. Null (legacy) counts as stale.
  final int? hashConsoleId;

  GameEntry({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.md5,
    required this.gameId,
    required this.matched,
    required this.noMatch,
    required this.lastScanned,
    required this.gameInfo,
    required this.progress,
    this.metadata,
    this.hashConsoleId,
  });

  /// A file that was listed but never hashed/matched.
  factory GameEntry.unscanned(String filePath,
          {int? fileSize, DateTime? lastScanned}) =>
      GameEntry(
        filePath: filePath,
        fileName: p.basename(filePath),
        fileSize: fileSize,
        md5: null,
        gameId: null,
        matched: false,
        noMatch: false,
        lastScanned: lastScanned ?? DateTime.now(),
        gameInfo: null,
        progress: null,
      );

  GameEntry copyWith({
    int? fileSize,
    String? md5,
    int? gameId,
    bool? matched,
    bool? noMatch,
    DateTime? lastScanned,
    GameInfo? gameInfo,
    UserProgress? progress,
    GameMetadata? metadata,
    int? hashConsoleId,
  }) =>
      GameEntry(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize ?? this.fileSize,
        md5: md5 ?? this.md5,
        gameId: gameId ?? this.gameId,
        matched: matched ?? this.matched,
        noMatch: noMatch ?? this.noMatch,
        lastScanned: lastScanned ?? this.lastScanned,
        gameInfo: gameInfo ?? this.gameInfo,
        progress: progress ?? this.progress,
        metadata: metadata ?? this.metadata,
        hashConsoleId: hashConsoleId ?? this.hashConsoleId,
      );

  factory GameEntry.fromJson(Map<String, dynamic> j) => GameEntry(
        filePath: j['filePath'] as String,
        fileName: j['fileName'] as String,
        fileSize: (j['fileSize'] as num?)?.toInt(),
        md5: j['md5'] as String?,
        gameId: (j['gameId'] as num?)?.toInt(),
        matched: j['matched'] as bool? ?? false,
        noMatch: j['noMatch'] as bool? ?? false,
        lastScanned: DateTime.parse(j['lastScanned'] as String),
        gameInfo: j['gameInfo'] == null
            ? null
            : GameInfo.fromJson(j['gameInfo'] as Map<String, dynamic>),
        progress: j['progress'] == null
            ? null
            : UserProgress.fromJson(j['progress'] as Map<String, dynamic>),
        metadata: j['metadata'] == null
            ? null
            : GameMetadata.fromJson(j['metadata'] as Map<String, dynamic>),
        hashConsoleId: (j['hashConsoleId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'fileSize': fileSize,
        'md5': md5,
        'gameId': gameId,
        'matched': matched,
        'noMatch': noMatch,
        'lastScanned': lastScanned.toIso8601String(),
        'gameInfo': gameInfo?.toJson(),
        'progress': progress?.toJson(),
        'metadata': metadata?.toJson(),
        'hashConsoleId': hashConsoleId,
      };
}
