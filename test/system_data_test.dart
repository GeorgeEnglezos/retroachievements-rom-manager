import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';

GameEntry _entry(String path) => GameEntry(
      filePath: path,
      fileName: path.split(RegExp(r'[\\/]')).last,
      fileSize: 1,
      md5: 'm',
      gameId: 1,
      matched: true,
      noMatch: false,
      lastScanned: DateTime.parse('2026-06-13T10:00:00.000'),
      gameInfo: null,
      progress: null,
    );

void main() {
  test('SystemData round-trips games and dismissed pairs', () {
    final data = SystemData(
      systemId: '',
      systemPath: r'E:\ROMs\SNES',
      games: [_entry(r'E:\ROMs\SNES\a.sfc'), _entry(r'E:\ROMs\SNES\b.sfc')],
      dismissedDuplicatePairs: {r'E:\ROMs\SNES\a.sfc|E:\ROMs\SNES\b.sfc'},
    );

    final restored = SystemData.fromJson(data.toJson());

    expect(restored.systemPath, r'E:\ROMs\SNES');
    expect(restored.games.length, 2);
    expect(restored.dismissedDuplicatePairs,
        contains(r'E:\ROMs\SNES\a.sfc|E:\ROMs\SNES\b.sfc'));
  });

  test('SystemData round-trips with no pairs', () {
    final data = SystemData(
      systemId: '',
      systemPath: r'E:\ROMs\NES',
      games: const [],
      dismissedDuplicatePairs: const {},
    );

    final restored = SystemData.fromJson(data.toJson());

    expect(restored.dismissedDuplicatePairs, isEmpty);
    expect(restored.games, isEmpty);
  });

  test('legacy file with a ranking block still loads (key ignored)', () {
    final back = SystemData.fromJson({
      'systemId': 'legacy',
      'systemPath': r'E:\ROMs\SNES',
      'games': <dynamic>[],
      'dismissedDuplicatePairs': <dynamic>[],
      'ranking': {
        'systemPath': r'E:\ROMs\SNES',
        'mode': 'quick',
        'status': 'completed',
        'state': <String, dynamic>{},
        'ranking': [
          {'gameId': 1, 'filePath': r'E:\ROMs\SNES\a.sfc', 'title': 'A'},
        ],
      },
    });
    expect(back.systemId, 'legacy');
    expect(back.games, isEmpty);
    // The dropped ranking key never round-trips back out.
    expect(back.toJson().containsKey('ranking'), isFalse);
  });

  test('round-trips systemId and consoleId', () {
    final data = SystemData(
      systemId: 'abc123',
      systemPath: r'C:\roms\snes',
      games: const [],
      dismissedDuplicatePairs: <String>{},
      consoleId: 3,
    );
    final back = SystemData.fromJson(data.toJson());
    expect(back.systemId, 'abc123');
    expect(back.consoleId, 3);
  });

  test('fromJson defaults systemId to empty and consoleId to null (legacy files)', () {
    final back = SystemData.fromJson({
      'systemPath': r'C:\roms\snes',
      'games': <dynamic>[],
    });
    expect(back.systemId, '');
    expect(back.consoleId, isNull);
  });

  test('copyWith overrides only the given fields', () {
    final data = SystemData(
      systemId: '',
      systemPath: r'C:\roms\snes',
      games: const [],
      dismissedDuplicatePairs: <String>{},
      consoleId: null,
    );
    final updated = data.copyWith(systemId: 'new-id', consoleId: 3);
    expect(updated.systemId, 'new-id');
    expect(updated.consoleId, 3);
    expect(updated.systemPath, data.systemPath);
  });
}
