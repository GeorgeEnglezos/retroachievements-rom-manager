import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/game_metadata.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/models/user_progress.dart';

void main() {
  test('GameEntry round-trips through JSON with info and progress', () {
    final entry = GameEntry(
      filePath: r'E:\ROMs\SNES\smw.sfc',
      fileName: 'smw.sfc',
      fileSize: 524288,
      md5: 'abc123',
      gameId: 228,
      matched: true,
      noMatch: false,
      lastScanned: DateTime.parse('2026-06-13T10:00:00.000'),
      gameInfo: GameInfo(
        gameId: 228,
        title: 'Blahblah World',
        consoleName: 'SNES',
        consoleId: 3,
        achievementCount: 50,
        imageIcon: '/Images/1.png',
      ),
      progress: UserProgress(
        gameId: 228,
        earnedAchievements: 5,
        earnedHardcore: 2,
        lastPlayed: DateTime.parse('2026-06-01T12:00:00.000'),
      ),
    );

    final restored = GameEntry.fromJson(entry.toJson());

    expect(restored.filePath, entry.filePath);
    expect(restored.md5, 'abc123');
    expect(restored.matched, isTrue);
    expect(restored.gameInfo!.title, 'Blahblah World');
    expect(restored.progress!.earnedAchievements, 5);
    expect(restored.lastScanned, entry.lastScanned);
  });

  test('GameEntry round-trips when unmatched (null info and progress)', () {
    final entry = GameEntry(
      filePath: r'E:\ROMs\SNES\unknown.sfc',
      fileName: 'unknown.sfc',
      fileSize: 100,
      md5: 'deadbeef',
      gameId: null,
      matched: false,
      noMatch: true,
      lastScanned: DateTime.parse('2026-06-13T10:00:00.000'),
      gameInfo: null,
      progress: null,
      hashConsoleId: 19,
    );

    final restored = GameEntry.fromJson(entry.toJson());

    expect(restored.gameInfo, isNull);
    expect(restored.progress, isNull);
    expect(restored.noMatch, isTrue);
    expect(restored.hashConsoleId, 19);
  });

  test('copyWith changes only the given fields', () {
    final entry = GameEntry(
      filePath: 'a/b.sfc',
      fileName: 'b.sfc',
      fileSize: 10,
      md5: 'aa',
      gameId: 5,
      matched: true,
      noMatch: false,
      lastScanned: DateTime(2026, 1, 1),
      gameInfo: null,
      progress: null,
      hashConsoleId: 3,
    );

    final copy = entry.copyWith(
      lastScanned: DateTime(2026, 2, 2),
      progress: UserProgress(gameId: 5, earnedAchievements: 4, earnedHardcore: 1),
    );

    expect(copy.filePath, 'a/b.sfc');
    expect(copy.md5, 'aa');
    expect(copy.gameId, 5);
    expect(copy.matched, isTrue);
    expect(copy.hashConsoleId, 3);
    expect(copy.lastScanned, DateTime(2026, 2, 2));
    expect(copy.progress!.earnedAchievements, 4);
  });

  test('unscanned builds an all-null entry from a path', () {
    final entry = GameEntry.unscanned('roms/snes/smw.sfc', fileSize: 99);

    expect(entry.filePath, 'roms/snes/smw.sfc');
    expect(entry.fileName, 'smw.sfc');
    expect(entry.fileSize, 99);
    expect(entry.md5, isNull);
    expect(entry.gameId, isNull);
    expect(entry.matched, isFalse);
    expect(entry.noMatch, isFalse);
    expect(entry.gameInfo, isNull);
    expect(entry.progress, isNull);
    expect(entry.hashConsoleId, isNull);
  });

  test('third-party metadata round-trips through JSON', () {
    final entry = GameEntry(
      filePath: 'ps3/racer.iso',
      fileName: 'racer.iso',
      fileSize: 1,
      md5: null,
      gameId: null,
      matched: false,
      noMatch: false,
      lastScanned: DateTime.parse('2026-07-01T10:00:00.000'),
      gameInfo: null,
      progress: null,
      metadata: const GameMetadata(
        providerId: 'screenscraper',
        title: 'Racer',
        publisher: 'Acme',
        imageUrl: 'https://cdn.example.com/r.png',
        matchConfidence: 0.9,
      ),
    );
    final restored = GameEntry.fromJson(entry.toJson());
    expect(restored.metadata!.title, 'Racer');
    expect(restored.metadata!.providerId, 'screenscraper');
    expect(restored.metadata!.imageUrl, 'https://cdn.example.com/r.png');
  });

  test('metadata is null on legacy JSON without the field', () {
    final restored = GameEntry.fromJson({
      'filePath': 'x',
      'fileName': 'x',
      'fileSize': 1,
      'md5': null,
      'gameId': null,
      'matched': false,
      'noMatch': true,
      'lastScanned': '2026-06-13T10:00:00.000',
    });
    expect(restored.metadata, isNull);
  });

  test('hashConsoleId is null on legacy JSON without the field', () {
    final restored = GameEntry.fromJson({
      'filePath': 'x',
      'fileName': 'x',
      'fileSize': 1,
      'md5': 'aa',
      'gameId': null,
      'matched': false,
      'noMatch': true,
      'lastScanned': '2026-06-13T10:00:00.000',
    });
    expect(restored.hashConsoleId, isNull);
  });
}
