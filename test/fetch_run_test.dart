import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/fetch_plan.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/game_metadata.dart';
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

class _FakeRa extends RaService {
  _FakeRa() : super(username: 'u', apiKey: 'k');

  int achievements = 24;
  List<CompletedGame>? sweepResult; // null -> throw

  @override
  Future<(GameInfo, UserProgress)> getGameInfoAndUserProgress(
      int gameId) async {
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
  late Library library;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScanProgress.instance.stop();
    romDir = Directory.systemTemp.createTempSync('fr_roms');
    dataDir = Directory.systemTemp.createTempSync('fr_data');
    metadataDir = Directory.systemTemp.createTempSync('fr_metadata');
    library = Library(baseDir: dataDir);
  });

  tearDown(() {
    ScanProgress.instance.stop();
    romDir.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
    metadataDir.deleteSync(recursive: true);
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
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
      raCache: RaCache(),
      detailCache: {}, // fresh cache, so the new count is fetched
      service: ra,
      consoleId: 1,
      hash: (path) async => 'abc',
      lookupGameId: (md5) async => 7,
    );

    expect(result.setUpdates, hasLength(1));
    expect(result.setUpdates.single, contains('Racer'));
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
        raCache: RaCache(),
        detailCache: {},
        service: _FakeRa(),
        consoleId: 1,
        hash: (path) async => 'abc',
        lookupGameId: (md5) async => 7,
      );
    }

    test('writes earned counts from the completion sweep', () async {
      await seedMatched();
      final ra = _FakeRa()
        ..sweepResult = [
          CompletedGame(
            gameId: 7,
            title: 'Racer 7',
            consoleName: 'Genesis',
            numAwarded: 9,
            numAwardedHardcore: 3,
            maxPossible: 24,
          ),
        ];

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(),
        detailCache: {},
        service: ra,
        consoleId: 1,
      );

      final game = result.saved.games.single;
      expect(game.progress!.earnedAchievements, 9);
      expect(game.progress!.earnedHardcore, 3);
      expect(result.message, isNull);
    });

    // A failed sweep that got written would zero every game's progress.
    test('a failed sweep writes nothing and returns a message', () async {
      await seedMatched();
      final before = (await library.load(romDir.path)).games.single;
      final ra = _FakeRa(); // sweepResult stays null, so it throws

      final result = await runFolderFetch(
        folderPath: romDir.path,
        plan: const FetchPlan(scope: FetchScope.all, progress: true),
        extensions: const {'md'},
        library: library,
        run: ScanRun()..start(),
        raCache: RaCache(),
        detailCache: {},
        service: ra,
        consoleId: 1,
      );

      expect(result.message, isNotNull);
      final after = (await library.load(romDir.path)).games.single;
      expect(after.progress?.earnedAchievements,
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
        raCache: RaCache(),
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
        raCache: RaCache(),
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
          raCache: RaCache(),
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
