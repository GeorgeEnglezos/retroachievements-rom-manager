import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/user_progress.dart';
import 'package:rarm/services/fetch_engine.dart';
import 'package:rarm/services/fetch_pipeline.dart';
import 'package:rarm/services/ra_cache.dart';
import 'package:rarm/services/ra_service.dart';

GameInfo _info(int gameId) => GameInfo(
      gameId: gameId,
      title: 'Racer',
      consoleName: 'Genesis',
      consoleId: 1,
      achievementCount: 24,
    );

GameEntry _savedEntry({GameInfo? info}) => GameEntry(
      filePath: 'C:/g/dashrunner.md',
      fileName: 'dashrunner.md',
      fileSize: null,
      md5: 'abc',
      gameId: 7,
      matched: true,
      noMatch: false,
      lastScanned: DateTime(2026, 7, 1),
      gameInfo: info,
      progress: null,
    );

class _FakeRa extends RaService {
  _FakeRa() : super(username: 'u', apiKey: 'k');

  int detailCalls = 0;
  bool throwDetail = false;
  List<CompletedGame>? sweepResult; // null -> throw

  @override
  Future<(GameInfo, UserProgress)> getGameInfoAndUserProgress(
      int gameId) async {
    detailCalls++;
    if (throwDetail) throw Exception('network down');
    return (
      _info(gameId),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveGameDetail', () {
    test('uses saved entry without hitting the network', () async {
      final ra = _FakeRa();
      final detail = await resolveGameDetail(
          gameId: 7, service: ra, cache: {}, saved: _savedEntry(info: _info(7)));
      expect(ra.detailCalls, 0);
      expect(detail.$1.title, 'Racer');
    });

    test('falls back to network when no saved info, then caches', () async {
      final ra = _FakeRa();
      final cache = <int, (GameInfo, UserProgress)>{};
      await resolveGameDetail(gameId: 7, service: ra, cache: cache, saved: null);
      await resolveGameDetail(gameId: 7, service: ra, cache: cache, saved: null);
      expect(ra.detailCalls, 1); // second call served from cache
    });

    test('saved entry without gameInfo still goes to network', () async {
      final ra = _FakeRa();
      await resolveGameDetail(
          gameId: 7, service: ra, cache: {}, saved: _savedEntry(info: null));
      expect(ra.detailCalls, 1);
    });
  });

  group('tryResolveGameDetail', () {
    test('returns detail on success', () async {
      final detail = await tryResolveGameDetail(
          gameId: 7, service: _FakeRa(), cache: {}, logContext: 'test');
      expect(detail, isNotNull);
      expect(detail!.$1.title, 'Racer');
    });

    test('returns null and swallows a network failure', () async {
      final detail = await tryResolveGameDetail(
          gameId: 7,
          service: _FakeRa()..throwDetail = true,
          cache: {},
          logContext: 'test');
      expect(detail, isNull);
    });
  });

  group('applyFetchResultToRom', () {
    late Directory cacheDir;
    late RaCache raCache;

    setUp(() {
      cacheDir = Directory.systemTemp.createTempSync('ra_cache');
      raCache = RaCache(baseDir: cacheDir); // empty -> no basic offline info
    });

    tearDown(() => cacheDir.deleteSync(recursive: true));

    RomResult rom() => RomResult(filePath: 'C:/g/dashrunner.md', fileName: 'dashrunner.md');

    FetchResult res({String? md5 = 'abc', int? gameId = 7}) => FetchResult(
          filePath: 'C:/g/dashrunner.md',
          md5: md5,
          gameId: gameId,
          matched: gameId != null,
          noMatch: md5 != null && gameId == null,
        );

    Future<void> apply(RomResult r, FetchResult f, _FakeRa ra) =>
        applyFetchResultToRom(
          res: f,
          rom: r,
          consoleId: 1,
          service: ra,
          raCache: raCache,
          detailCache: {},
          logContext: 'test',
          mutate: (fn) => fn(),
        );

    test('matched result populates the rom with detail and progress', () async {
      final r = rom();
      await apply(r, res(), _FakeRa());
      expect(r.status, RomStatus.supported);
      expect(r.md5Hash, 'abc');
      expect(r.hashConsoleId, 1);
      expect(r.gameId, 7);
      expect(r.gameTitle, 'Racer');
      expect(r.earnedAchievements, 5);
      expect(r.earnedHardcore, 2);
    });

    test('detail failure still marks supported with a placeholder title',
        () async {
      final r = rom();
      await apply(r, res(), _FakeRa()..throwDetail = true);
      expect(r.status, RomStatus.supported);
      expect(r.gameTitle, 'Game #7');
    });

    test('detail failure keeps an already-known title', () async {
      final r = rom()..gameTitle = 'Racer';
      await apply(r, res(), _FakeRa()..throwDetail = true);
      expect(r.gameTitle, 'Racer');
    });

    test('noMatch marks the rom unsupported', () async {
      final r = rom();
      await apply(r, res(gameId: null), _FakeRa());
      expect(r.status, RomStatus.unsupported);
      expect(r.md5Hash, 'abc');
    });

    test('hash failure marks the rom as an error', () async {
      final r = rom();
      await apply(r, res(md5: null, gameId: null), _FakeRa());
      expect(r.status, RomStatus.error);
      expect(r.errorMessage, contains('console 1'));
    });
  });

  group('fetchCompletionSweep', () {
    test('success maps games by id', () async {
      final ra = _FakeRa()
        ..sweepResult = [
          CompletedGame(
              gameId: 7, title: 'Racer', consoleName: 'Genesis',
              numAwarded: 3, maxPossible: 24),
        ];
      final sweep = await fetchCompletionSweep(ra, 'test');
      expect(sweep.byGameId!.keys, [7]);
      expect(sweep.userMessage, isNull);
    });

    test('network failure returns null map and a message', () async {
      final sweep = await fetchCompletionSweep(_FakeRa(), 'test');
      expect(sweep.byGameId, isNull);
      expect(sweep.userMessage, contains('failed'));
    });

    test('empty sweep is treated as failure (never zero progress)', () async {
      final ra = _FakeRa()..sweepResult = [];
      final sweep = await fetchCompletionSweep(ra, 'test');
      expect(sweep.byGameId, isNull);
      expect(sweep.userMessage, contains('No progress data'));
    });
  });
}
