import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/services/folder_freshness.dart';

GameEntry _entry(String path, int size) => GameEntry(
      filePath: path,
      fileName: path,
      fileSize: size,
      md5: null,
      gameId: null,
      matched: false,
      noMatch: false,
      lastScanned: DateTime(2026),
      gameInfo: null,
      progress: null,
    );

void main() {
  test('classifies gone, changed, fresh, and skips empty', () {
    final stored = {
      'gone': [_entry('gone/a.gba', 10)],
      'changed': [_entry('changed/a.gba', 10)],
      'fresh': [_entry('fresh/a.gba', 10)],
      'empty': <GameEntry>[],
    };
    final disk = {
      'changed': {'changed/a.gba': 99}, // size differs
      'fresh': {'fresh/a.gba': 10},
      'empty': <String, int>{},
    };

    final r = classifyFolders(
      systemPaths: stored.keys.toList(),
      storedGames: (p) => stored[p]!,
      folderExists: (p) => p != 'gone',
      currentSizes: (p) => disk[p] ?? {},
    );

    expect(r.gone, ['gone']);
    expect(r.changed, ['changed']);
    expect(r.hasStale, isTrue);
  });
}
