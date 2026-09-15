import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/scan_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late Library lib;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('lib_test');
    lib = Library(baseDir: tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('save assigns a systemId from the path and load returns it', () async {
    final saved = await lib.save(SystemData(
      systemId: '',
      systemPath: p.join(tmp.path, 'snes'),
      games: const [],
      dismissedDuplicatePairs: <String>{},
      consoleId: 3,
    ));
    expect(saved.systemId, isNotEmpty);

    final loaded = await lib.load(p.join(tmp.path, 'snes'));
    expect(loaded.systemId, saved.systemId);
    expect(loaded.consoleId, 3);
  });

  test('load of an unknown path returns empty data with empty id', () async {
    final loaded = await lib.load(p.join(tmp.path, 'never'));
    expect(loaded.systemId, '');
    expect(loaded.games, isEmpty);
  });

  test('systemId is stable across repeated saves', () async {
    final path = p.join(tmp.path, 'snes');
    final first = await lib.save(SystemData(
      systemId: '', systemPath: path, games: const [],
      dismissedDuplicatePairs: <String>{}, consoleId: null));
    final again = await lib.save(first.copyWith(consoleId: 3));
    expect(again.systemId, first.systemId);
  });

  test('data persists to disk and is read back by a fresh instance', () async {
    final path = p.join(tmp.path, 'snes');
    final saved = await lib.save(SystemData(
        systemId: '', systemPath: path, games: const [],
        dismissedDuplicatePairs: <String>{}, consoleId: 7));

    final fresh = Library(baseDir: tmp);
    final loaded = await fresh.load(path);
    expect(loaded.systemId, saved.systemId);
    expect(loaded.consoleId, 7);
  });

  test('summaries and searchIndex are derived from saved games', () async {
    final path = p.join(tmp.path, 'snes');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(p.join(path, 'game.sfc'))],
    ));
    final summaries = await lib.summaries();
    expect(summaries, hasLength(1));
    expect(summaries.first.systemPath, path);
    expect(summaries.first.consoleId, 3);
    expect(summaries.first.totalGames, 1);

    final rows = await lib.searchIndex();
    expect(rows, hasLength(1));
  });

  test('a system with no games left is hidden from summaries', () async {
    await lib.save(SystemData(
      systemId: '', systemPath: p.join(tmp.path, 'snes'),
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: const [],
    ));
    expect(await lib.summaries(), isEmpty);
  });

  test('removeGame drops the entry from memory and disk', () async {
    final path = p.join(tmp.path, 'snes');
    final keep = p.join(path, 'keep.sfc');
    final gone = p.join(path, 'gone.sfc');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(keep), GameEntry.unscanned(gone)],
    ));

    await lib.removeGame(gone);

    expect((await lib.load(path)).games.map((g) => g.filePath), [keep]);

    // A fresh instance reads the rewritten file; the removal is on disk.
    final fresh = Library(baseDir: tmp);
    expect((await fresh.load(path)).games.map((g) => g.filePath), [keep]);
  });

  test('removeGame of an unknown path is a no-op', () async {
    final path = p.join(tmp.path, 'snes');
    final keep = p.join(path, 'keep.sfc');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(keep)],
    ));

    await lib.removeGame(p.join(path, 'never-existed.sfc'));

    expect((await lib.load(path)).games, hasLength(1));
  });

  test('deleteRom reports the file gone and drops its library entry',
      () async {
    final path = p.join(tmp.path, 'snes');
    final rom = p.join(path, 'game.sfc');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(rom)],
    ));

    expect(await lib.deleteRom(rom, recycle: (_) async => true), isTrue);
    expect((await lib.load(path)).games, isEmpty);
  });

  test('deleteRom keeps the entry when recycling fails', () async {
    final path = p.join(tmp.path, 'snes');
    final rom = p.join(path, 'game.sfc');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(rom)],
    ));

    expect(await lib.deleteRom(rom, recycle: (_) async => false), isFalse);
    expect((await lib.load(path)).games, hasLength(1));
  });

  test('allRomPaths returns every scanned ROM file path', () async {
    final path = p.join(tmp.path, 'psx');
    final rom = p.join(path, 'Racer.zip');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 12,
      games: [GameEntry.unscanned(rom)],
    ));

    expect(await lib.allRomPaths(), contains(rom));
  });

  test('removeGame drops the entry from every overlapping system', () async {
    final parent = p.join(tmp.path, 'roms');
    final child = p.join(parent, 'snes');
    final rom = p.join(child, 'game.sfc');
    for (final sysPath in [parent, child]) {
      await lib.save(SystemData(
        systemId: '', systemPath: sysPath,
        dismissedDuplicatePairs: <String>{}, consoleId: 3,
        games: [GameEntry.unscanned(rom)],
      ));
    }

    await lib.removeGame(rom);

    expect((await lib.load(parent)).games, isEmpty);
    expect((await lib.load(child)).games, isEmpty);
  });

  test('gamesFor applies the same exclude/ignore filters as summaries',
      () async {
    final path = p.join(tmp.path, 'snes');
    final keep = p.join(path, 'keep.sfc');
    final excluded = p.join(path, 'excluded.sfc');
    final nested = p.join(path, 'bios', 'nested.sfc');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [
        GameEntry.unscanned(keep),
        GameEntry.unscanned(excluded),
        GameEntry.unscanned(nested),
      ],
    ));

    expect((await lib.gamesFor(path)).map((g) => g.filePath),
        [keep, excluded, nested]);

    await ScanSettings.setExcludedFiles([excluded]);
    await ScanSettings.setIgnoredFolders('bios');

    expect((await lib.gamesFor(path)).map((g) => g.filePath), [keep]);
  });

  test('gamesFor returns nothing for an ignored system', () async {
    final path = p.join(tmp.path, 'bios');
    await lib.save(SystemData(
      systemId: '', systemPath: path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(p.join(path, 'game.sfc'))],
    ));

    await ScanSettings.setIgnoredFolders('bios');

    expect(await lib.gamesFor(path), isEmpty);
    expect(await lib.summaries(), isEmpty);
  });

  test('systems outside the current library root drop out of summaries',
      () async {
    final root = p.join(tmp.path, 'current');
    SharedPreferences.setMockInitialValues({'last_folder': root});
    final inRoot = p.join(root, 'snes');
    final stale = p.join(tmp.path, 'old', 'nes');
    for (final path in [inRoot, stale]) {
      await lib.save(SystemData(
        systemId: '', systemPath: path,
        dismissedDuplicatePairs: <String>{}, consoleId: 3,
        games: [GameEntry.unscanned(p.join(path, 'game.sfc'))],
      ));
    }

    final summaries = await lib.summaries();
    expect(summaries, hasLength(1));
    expect(summaries.first.systemPath, inRoot);
  });

  test('a system whose folder is gone drops out of every derived view',
      () async {
    final dir = await Directory(p.join(tmp.path, 'ps4')).create();
    await lib.save(SystemData(
      systemId: '', systemPath: dir.path,
      dismissedDuplicatePairs: <String>{}, consoleId: 3,
      games: [GameEntry.unscanned(p.join(dir.path, 'game.iso'))],
    ));

    await lib.refreshMissingSystems();
    expect(await lib.summaries(), hasLength(1));

    await dir.delete(recursive: true);
    await lib.refreshMissingSystems();

    expect(lib.isSystemMissing(dir.path), isTrue);
    // Case and separators must not decide whether a system is hidden.
    expect(lib.isSystemMissing(dir.path.toUpperCase()), isTrue);
    expect(await lib.summaries(), isEmpty);
    expect(await lib.searchIndex(), isEmpty);
    expect(await lib.gamesFor(dir.path), isEmpty);
    // The data itself is kept, so remounting the drive brings it back.
    expect((await lib.load(dir.path)).games, hasLength(1));

    await Directory(dir.path).create();
    await lib.refreshMissingSystems();
    expect(await lib.summaries(), hasLength(1));
  });

  test('pruneMissingSystems deletes only systems whose folder is gone',
      () async {
    final live = await Directory(p.join(tmp.path, 'snes')).create();
    final gone = await Directory(p.join(tmp.path, 'ps4')).create();
    for (final d in [live, gone]) {
      await lib.save(SystemData(
        systemId: '', systemPath: d.path,
        dismissedDuplicatePairs: <String>{}, consoleId: 3,
        games: [GameEntry.unscanned(p.join(d.path, 'game.iso'))],
      ));
    }

    await gone.delete(recursive: true);
    expect(await lib.pruneMissingSystems(), 1);

    // The live system survives; the missing one is gone from a fresh instance.
    final fresh = Library(baseDir: tmp);
    expect(await fresh.summaries(), hasLength(1));
    expect((await fresh.load(gone.path)).games, isEmpty);
    expect((await fresh.load(live.path)).games, hasLength(1));

    // Idempotent: nothing left to prune.
    expect(await lib.pruneMissingSystems(), 0);
  });

  test('gamesFor of an unscanned path is empty', () async {
    expect(await lib.gamesFor(p.join(tmp.path, 'never')), isEmpty);
  });

  test('init adopts legacy filename stem as systemId and deletes home.json',
      () async {
    final systemsDir = Directory(p.join(tmp.path, 'data', 'systems'));
    await systemsDir.create(recursive: true);
    const stem = 'deadbeef';
    final legacy = <String, dynamic>{
      'systemPath': p.join(tmp.path, 'snes'),
      'games': <dynamic>[],
      'ranking': null,
      'dismissedDuplicatePairs': <dynamic>[],
    };
    await File(p.join(systemsDir.path, '$stem.json'))
        .writeAsString(jsonEncode(legacy));
    final home = File(p.join(tmp.path, 'data', 'home.json'));
    await home.writeAsString(jsonEncode(<String, dynamic>{
      'systems': <dynamic>[], 'searchIndex': <dynamic>[],
    }));

    final fresh = Library(baseDir: tmp);
    await fresh.init();

    final loaded = await fresh.load(p.join(tmp.path, 'snes'));
    expect(loaded.systemId, stem);
    expect(await home.exists(), isFalse);
  });
}
