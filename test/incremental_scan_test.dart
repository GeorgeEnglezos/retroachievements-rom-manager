import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/services/incremental_scan.dart';

GameEntry _entry(String path, int? size) => GameEntry(
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
  test('unchanged when paths and sizes all match', () {
    final stored = [_entry('a', 10), _entry('b', 20)];
    expect(folderUnchanged(stored, {'a': 10, 'b': 20}), isTrue);
  });

  test('changed when a file size differs', () {
    expect(folderUnchanged([_entry('a', 10)], {'a': 11}), isFalse);
  });

  test('changed when a file is added or removed', () {
    expect(folderUnchanged([_entry('a', 10)], {'a': 10, 'b': 20}), isFalse);
    expect(folderUnchanged([_entry('a', 10), _entry('b', 20)], {'a': 10}),
        isFalse);
  });

  test('changed when a path is renamed', () {
    expect(folderUnchanged([_entry('a', 10)], {'b': 10}), isFalse);
  });

  test('never-scanned folder is always considered changed', () {
    expect(folderUnchanged(const [], {'a': 10}), isFalse);
    expect(folderUnchanged(const [], const {}), isFalse);
  });

  test('null stored size matches on presence alone', () {
    expect(folderUnchanged([_entry('a', null)], {'a': 999}), isTrue);
  });

  group('isResolvedEntry', () {
    GameEntry entry({
      bool matched = false,
      bool noMatch = false,
      int? hashConsoleId,
    }) =>
        GameEntry(
          filePath: 'a',
          fileName: 'a',
          fileSize: null,
          md5: null,
          gameId: null,
          matched: matched,
          noMatch: noMatch,
          lastScanned: DateTime(2026),
          gameInfo: null,
          progress: null,
          hashConsoleId: hashConsoleId,
        );

    test('an unscanned file is never resolved', () {
      expect(isResolvedEntry(null, 4), isFalse);
      expect(isResolvedEntry(entry(), 4), isFalse);
    });

    test('a matched entry is resolved whatever the console', () {
      expect(isResolvedEntry(entry(matched: true, hashConsoleId: 7), 4), isTrue);
    });

    test('noMatch counts only for the console it was hashed as', () {
      expect(isResolvedEntry(entry(noMatch: true, hashConsoleId: 4), 4), isTrue);
      // Hashed as the wrong system; must be re-hashed, so it still counts
      // toward the sweep total (see [[wii-stale-console45-hash]]).
      expect(
          isResolvedEntry(entry(noMatch: true, hashConsoleId: 45), 4), isFalse);
    });
  });
}
