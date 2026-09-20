import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/fetch_plan.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/game_metadata.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/models/user_progress.dart';
import 'package:rarm/services/fetch_run.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/metadata/metadata_provider.dart';
import 'package:rarm/services/metadata_cache.dart';
import 'package:rarm/services/ra_cache.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/services/scan_progress.dart';
import 'package:rarm/services/scan_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameInfo _info(int gameId, {int achievements = 24}) => GameInfo(
      gameId: gameId,
      title: 'Racer $gameId',
      consoleName: 'Genesis',
      consoleId: 1,
      achievementCount: achievements,
    );

CompletedGame _completed(int gameId,
        {int awarded = 0, int hardcore = 0, int maxPossible = 24}) =>
    CompletedGame(
      gameId: gameId,
      title: 'Racer $gameId',
      consoleName: 'Genesis',
      numAwarded: awarded,
      numAwardedHardcore: hardcore,
      maxPossible: maxPossible,
    );

class _FakeRa extends RaService {
  _FakeRa() : super(username: 'u', apiKey: 'k');

  int achievements = 24;
  List<CompletedGame>? sweepResult; // null -> throw
  int detailCalls = 0;

  @override
  Future<(GameInfo, UserProgress)> getGameInfoAndUserProgress(
      int gameId) async {
    detailCalls++;
    return (
      _info(gameId, achievements: achievements),
      UserProgress(gameId: gameId, earnedAchievements: 5, earnedHardcore: 2),
    );
  }

  @override
  Future<List<CompletedGame>> getUserCompletionProgress() async {
    final r = sweepResult;
    if (r == null) throw Exception('network down');
    return r;
  }
}

class _FakeProvider implements MetadataProvider {
  int lookups = 0;

  @override
  String get id => 'fake';

  @override
  String get label => 'Fake';

  @override
  bool supports(int consoleId) => true;

  @override
  Future<GameMetadata?> lookup(
      {required String name, required int consoleId}) async {
    lookups++;
    return GameMetadata(providerId: id, title: name);
  }
}

// Display-only consoles live in ConsoleMap.displayNames under negative ids, so
// isRaSupported is false for them and the runner takes the metadata branch.
const _displayOnlyConsoleId = -3; // PlayStation 3

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory romDir;
  late Directory dataDir;
  late Directory metadataDir;
  late Directory cacheDir;
  late Library library;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScanProgress.instance.stop();
    romDir = Directory.systemTemp.createTempSync('fr_roms');
    dataDir = Directory.systemTemp.createTempSync('fr_data');
    metadataDir = Directory.systemTemp.createTempSync('fr_metadata');
    cacheDir = Directory.systemTemp.createTempSync('fr_cache');
    library = Library(baseDir: dataDir);
  });

  tearDown(() {
    ScanProgress.instance.stop();
    romDir.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
    metadataDir.deleteSync(recursive: true);
    cacheDir.deleteSync(recursive: true);
  });

  File rom(String name) =>
      File(p.join(romDir.path, name))..writeAsStringSync('x');

  test('hashes and matches every file, saving the result', () async {
    rom('one.md');
    rom('two.md');
    final run = ScanRun()..start();

    final result = await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: run,
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'md5-${p.basename(path)}',
      lookupGameId: (md5) async => md5.hashCode.abs() % 1000,
    );

    expect(result.saved.games, hasLength(2));
    expect(result.saved.games.every((g) => g.matched), isTrue);
    expect(result.saved.games.every((g) => g.gameInfo != null), isTrue);
    expect(result.cancelled, isFalse);

    // Persisted, not just returned.
    final reloaded = await library.load(romDir.path);
    expect(reloaded.games.where((g) => g.matched), hasLength(2));
  });

  test('ticks the run once per file and reports its target count', () async {
    rom('one.md');
    rom('two.md');
    final run = ScanRun()..start();
    var reported = 0;

    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: run,
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'md5-${p.basename(path)}',
      lookupGameId: (md5) async => 7,
      onTargets: (n) => reported = n,
    );

    expect(reported, 2);
    expect(run.done, 2);
  });

  test('emits each entry so callers can update rows live', () async {
    rom('one.md');
    final emitted = <GameEntry>[];

    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
      onEntry: emitted.add,
    );

    expect(emitted, hasLength(1));
    expect(emitted.single.gameId, 7);
  });

  test('cancel stops mid-folder and still saves what was done', () async {
    rom('one.md');
    rom('two.md');
    rom('three.md');
    final run = ScanRun()..start();

    final result = await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: run,
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
      onEntry: (_) => ScanProgress.instance.requestCancel(),
    );

    expect(result.cancelled, isTrue);
    expect(result.saved.games.where((g) => g.matched), hasLength(1));
    // Unprocessed files are still listed, just unscanned.
    expect(result.saved.games, hasLength(3));
  });

  test('only unfetched skips already resolved entries', () async {
    rom('one.md');
    rom('two.md');
    // First pass resolves both.
    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
    );

    var hashed = 0;
    final run = ScanRun()..start();
    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: run,
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async {
        hashed++;
        return 'abc';
      },
      lookupGameId: (md5) async => 7,
    );

    expect(hashed, 0);
    expect(run.done, 0);
  });

  test('re-fetch all re-hashes resolved entries', () async {
    rom('one.md');
    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
    );

    var hashed = 0;
    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(
          scope: FetchScope.all, match: true, matchReFetchAll: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: _FakeRa(),
      consoleId: 1,
      hash: (path) async {
        hashed++;
        return 'abc';
      },
      lookupGameId: (md5) async => 7,
    );

    expect(hashed, 1);
  });

  test('reports titles whose achievement set grew', () async {
    rom('one.md');
    final ra = _FakeRa()..achievements = 10;
    await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(scope: FetchScope.all, match: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {},
      service: ra,
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
    );

    ra.achievements = 20;
    final result = await runFolderFetch(
      folderPath: romDir.path,
      plan: const FetchPlan(
          scope: FetchScope.all, match: true, matchReFetchAll: true),
      extensions: const {'md'},
      library: library,
      run: ScanRun()..start(),
      raCache: RaCache(baseDir: cacheDir),
      detailCache: {}, // fresh cache, so the new count is fetched
      service: ra,
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
    );

    expect(result.setUpdates, hasLength(1));
    expect(result.setUpdates.single, contains('Racer'));
  });

  // The per-game call costs one request per matched ROM, which on a real
  // library is the whole API bill. Everything a row draws is already in the
  // cached console list, so a scan must not make that call.
  group('deferred game detail', () {
    RaGameListEntry listed(int gameId) => RaGameListEntry(
          gameId: gameId,
          title: 'Racer $gameId',
          consoleId: 1,
          imageIcon: '/Images/$gameId.png',
          achievementCount: 24,
          points: 300,
          hashes: const ['abc'],
        );

    test('a matched ROM is described from the cached list, with no API call',
        () async {
      rom('one.md');
      final cache = RaCache(baseDir: cacheDir);
      await cache.storeConsole(1, [listed(7)]);
      final ra = _FakeRa();

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, match: true, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: cache,
        detailCache: {},
        service: ra,
        consoleId: 1,
        progressByGameId: {7: _completed(7, awarded: 4, hardcore: 1)},
        hash: (path) async => 'abc',
        lookupGameId: (md5) async => 7,
      );

      final game = result.saved.games.single;
      expect(ra.detailCalls, 0);
      expect(game.gameInfo!.title, 'Racer 7');
      expect(game.gameInfo!.achievementCount, 24);
      expect(game.gameInfo!.points, 300);
      // The list row's thumbnail comes from the icon, which the list carries.
      expect(game.gameInfo!.imageIcon, '/Images/7.png');
      // Box art does not, and is left for the detail dialog to fetch.
      expect(game.gameInfo!.imageBoxArt, isNull);
      expect(game.progress!.earnedAchievements, 4);
      expect(game.progress!.earnedHardcore, 1);
    });

    // GetGameList ships roughly one hash per game, so a secondary dump resolves
    // through dorequest and has no list entry to describe it. Naming those is
    // worth the call; there are few per run.
    test('a game missing from the list still falls back to the per-game call',
        () async {
      rom('one.md');
      final cache = RaCache(baseDir: cacheDir);
      await cache.storeConsole(1, [listed(7)]); // game 9 is not in the list
      final ra = _FakeRa();

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, match: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: cache,
        detailCache: {},
        service: ra,
        consoleId: 1,
        hash: (path) async => 'zzz',
        lookupGameId: (md5) async => 9,
      );

      expect(ra.detailCalls, 1);
      expect(result.saved.games.single.gameInfo!.title, 'Racer 9');
    });

    // Re-hash every ROM re-processes entries a previous scan already enriched.
    // The cached list has no box art, so writing it straight over the stored
    // entry would delete art the user already has.
    test('re-hashing keeps rich detail an earlier scan already stored',
        () async {
      rom('one.md');
      final cache = RaCache(baseDir: cacheDir);
      await cache.storeConsole(1, [listed(7)]);
      await library.save(SystemData(
        systemId: '',
        systemPath: romDir.path,
        games: [
          GameEntry(
            filePath: p.join(romDir.path, 'one.md'),
            fileName: 'one.md',
            fileSize: 1,
            md5: 'abc',
            gameId: 7,
            matched: true,
            noMatch: false,
            lastScanned: DateTime(2026, 1, 1),
            gameInfo: GameInfo(
              gameId: 7,
              title: 'Racer 7',
              consoleName: 'Genesis',
              consoleId: 1,
              achievementCount: 24,
              imageIcon: '/Images/7.png',
              imageBoxArt: '/Images/box.png',
              genre: 'Racing',
            ),
            progress: null,
            hashConsoleId: 1,
          ),
        ],
        dismissedDuplicatePairs: <String>{},
        consoleId: 1,
      ));

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(
            scope: FetchScope.all, match: true, matchReFetchAll: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: cache,
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        hash: (path) async => 'abc',
        lookupGameId: (md5) async => 7,
      );

      final info = result.saved.games.single.gameInfo!;
      expect(info.imageBoxArt, '/Images/box.png');
      expect(info.genre, 'Racing');
    });

    // The set-update banner compares achievement counts across scans; the
    // cached list carries the count, so deferring the detail must not blind it.
    test('a grown set is still detected off the cached list', () async {
      rom('one.md');
      final cache = RaCache(baseDir: cacheDir);
      await cache.storeConsole(1, [listed(7)]);
      Future<FolderRunResult> scan() => runFolderFetch(
            folderPath: romDir.path,
            plan: const FetchPlan(scope: FetchScope.all, match: true),
            extensions: const {'md'},
            library: library,
            run: ScanRun()..start(),
            raCache: cache,
            detailCache: {},
            service: _FakeRa(),
            consoleId: 1,
            hash: (path) async => 'abc',
            lookupGameId: (md5) async => 7,
          );
      await scan(); // first scan records 24

      await cache.storeConsole(1, [
        RaGameListEntry(
          gameId: 7,
          title: 'Racer 7',
          consoleId: 1,
          achievementCount: 30, // RA revised the set
          hashes: const ['abc'],
        ),
      ]);
      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(
            scope: FetchScope.all, match: true, matchReFetchAll: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: cache,
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        hash: (path) async => 'abc',
        lookupGameId: (md5) async => 7,
      );

      expect(result.setUpdates.single, contains('Racer 7'));
    });
  });

  group('progress-only pass', () {
    Future<void> seedMatched() async {
      rom('one.md');
      await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, match: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        hash: (path) async => 'abc',
        lookupGameId: (md5) async => 7,
      );
    }

    test('writes earned counts from the caller\'s completion sweep', () async {
      await seedMatched();

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        progressByGameId: {7: _completed(7, awarded: 9, hardcore: 3)},
      );

      final game = result.saved.games.single;
      expect(game.progress!.earnedAchievements, 9);
      expect(game.progress!.earnedHardcore, 3);
    });

    // A game the sweep doesn't mention was never played, so it reads as zero
    // rather than keeping a count that is no longer true.
    test('a game missing from the sweep is written as zero', () async {
      await seedMatched();

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        progressByGameId: const {},
      );

      expect(result.saved.games.single.progress!.earnedAchievements, 0);
    });

    // The caller passes null when its sweep failed. Writing zeros then would
    // wipe every game's progress over a dropped connection.
    test('a null sweep writes nothing at all', () async {
      await seedMatched();
      final before = (await library.load(romDir.path)).games.single;

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
      );

      expect(result.saved.games.single.progress?.earnedAchievements,
          before.progress?.earnedAchievements);
    });
  });

  group('display-only consoles', () {
    test('fetches metadata when a provider supports the console', () async {
      rom('one.iso');
      final provider = _FakeProvider();

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, match: true),
        extensions: const {'iso'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        consoleId: _displayOnlyConsoleId,
        metadataProvider: provider,
        metadataCache: MetadataCache(baseDir: metadataDir),
      );

      expect(provider.lookups, 1);
      expect(result.saved.games.single.metadata, isNotNull);
    });

    test('records size only when no provider is configured', () async {
      rom('one.iso');

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, match: true),
        extensions: const {'iso'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(baseDir: cacheDir),
        detailCache: {},
        consoleId: _displayOnlyConsoleId,
      );

      final game = result.saved.games.single;
      expect(game.matched, isFalse);
      expect(game.metadata, isNull);
      expect(game.fileSize, greaterThan(0));
    });

    test('skips entries that already have metadata unless re-fetching all',
        () async {
      rom('one.iso');
      final provider = _FakeProvider();
      // Each call gets its own on-disk cache dir: MetadataCache persists hits
      // to disk, and a shared cache would short-circuit the third (re-fetch
      // all) call before it ever reaches the runner's target selection, which
      // is what this test is actually checking.
      final cacheDirs = <Directory>[];
      Future<void> fetch({bool all = false}) {
        final cacheDir = Directory.systemTemp.createTempSync('fr_metadata');
        cacheDirs.add(cacheDir);
        return runFolderFetch(
          folderPath: romDir.path,
          plan: FetchPlan(
              scope: FetchScope.all, match: true, matchReFetchAll: all),
          extensions: const {'iso'},
          library: library,
          run: ScanRun()..start(),
          raCache: RaCache(baseDir: cacheDir),
          detailCache: {},
          consoleId: _displayOnlyConsoleId,
          metadataProvider: provider,
          metadataCache: MetadataCache(baseDir: cacheDir),
        );
      }

      await fetch();
      expect(provider.lookups, 1);
      await fetch();
      expect(provider.lookups, 1); // skipped
      await fetch(all: true);
      expect(provider.lookups, 2);

      for (final d in cacheDirs) {
        d.deleteSync(recursive: true);
      }
    });
  });
}
