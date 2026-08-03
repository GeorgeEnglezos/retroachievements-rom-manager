import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/services/ra_cache.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('racache_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  RaGameListEntry entry(int id, List<String> hashes) => RaGameListEntry(
        gameId: id,
        title: 'Game $id',
        consoleId: 1,
        achievementCount: 10,
        points: 100,
        hashes: hashes,
      );

  test('storeConsole then lookup resolves md5 to gameId offline', () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa', 'bb']), entry(8, ['cc'])]);
    expect(await cache.lookupGameId('aa', 1), 7);
    expect(await cache.lookupGameId('cc', 1), 8);
    expect(await cache.lookupGameId('zz', 1), isNull);
  });

  test('lookup is case-insensitive', () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['abc123'])]);
    expect(await cache.lookupGameId('ABC123', 1), 7);
  });

  test('entryForGame returns basic info', () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    final e = await cache.entryForGame(7, 1);
    expect(e!.title, 'Game 7');
    expect(e.points, 100);
  });

  test('survives reload from disk', () async {
    await RaCache(baseDir: tmp).storeConsole(1, [entry(7, ['aa'])]);
    final fresh = RaCache(baseDir: tmp);
    expect(await fresh.lookupGameId('aa', 1), 7);
  });

  test('hasConsole false before store, true after', () async {
    final cache = RaCache(baseDir: tmp);
    expect(await cache.hasConsole(1), isFalse);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    expect(await cache.hasConsole(1), isTrue);
  });

  test('concurrent cold lookups both resolve (no load race)', () async {
    await RaCache(baseDir: tmp).storeConsole(1, [entry(7, ['aa'])]);
    final fresh = RaCache(baseDir: tmp);
    final results = await Future.wait([
      fresh.lookupGameId('aa', 1),
      fresh.lookupGameId('aa', 1),
    ]);
    expect(results, [7, 7]);
  });

  test('resolveGameId falls back online when offline index misses, then caches',
      () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]); // 'bb' not in the list
    final ra = _FakeRa()..onHash = {'bb': 42};

    // Offline hit: no online call.
    expect(await cache.resolveGameId(ra, 1, 'aa'), 7);
    expect(ra.hashCalls, 0);

    // Offline miss -> dorequest fallback resolves it.
    expect(await cache.resolveGameId(ra, 1, 'bb'), 42);
    expect(ra.hashCalls, 1);

    // Cached: a repeat stays offline (no second network call).
    expect(await cache.resolveGameId(ra, 1, 'bb'), 42);
    expect(ra.hashCalls, 1);
  });

  test('refreshing the list keeps hashes learned from the online fallback',
      () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    final ra = _FakeRa()..onHash = {'bb': 7};
    expect(await cache.resolveGameId(ra, 1, 'bb'), 7); // learned + persisted

    // "Refresh RA lists" re-pulls a list that still doesn't carry 'bb'; the
    // learned hash must survive, in memory and on disk.
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    expect(await cache.lookupGameId('bb', 1), 7);
    expect(await RaCache(baseDir: tmp).lookupGameId('bb', 1), 7);

    // Same via a cold instance, which must read the old file before merging.
    await RaCache(baseDir: tmp).storeConsole(1, [entry(7, ['aa'])]);
    expect(await RaCache(baseDir: tmp).lookupGameId('bb', 1), 7);
  });

  test('a game dropped from the refreshed list loses its learned hashes',
      () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    await cache.resolveGameId(_FakeRa()..onHash = {'bb': 7}, 1, 'bb');
    await cache.storeConsole(1, [entry(8, ['cc'])]); // 7 is gone from RA
    expect(await cache.lookupGameId('bb', 1), isNull);
    expect(await cache.lookupGameId('aa', 1), isNull);
  });

  test('resolveGameId returns null when neither offline nor online matches',
      () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    final ra = _FakeRa(); // onHash empty -> no match
    expect(await cache.resolveGameId(ra, 1, 'zz'), isNull);
    expect(ra.hashCalls, 1);
  });

  // Null means "RA has no such game" and is persisted as a confirmed no-match,
  // which unfetched-only rescans skip forever. A dead network or a timed-out
  // request must not look like that.
  test('resolveGameId throws when the online lookup fails', () async {
    final cache = RaCache(baseDir: tmp);
    await cache.storeConsole(1, [entry(7, ['aa'])]);
    final ra = _FakeRa()..hashThrows = true;
    expect(cache.resolveGameId(ra, 1, 'zz'), throwsA(isA<TimeoutException>()));
  });
}

/// Stubs the two network calls resolveGameId depends on so the fallback path is
/// testable offline.
class _FakeRa extends RaService {
  _FakeRa() : super(username: 'u', apiKey: 'k');
  Map<String, int> onHash = {};
  int hashCalls = 0;
  bool hashThrows = false;

  @override
  Future<int?> getGameIdByHash(String md5Hash) async {
    hashCalls++;
    if (hashThrows) throw TimeoutException('dead socket');
    return onHash[md5Hash];
  }

  @override
  Future<List<RaGameListEntry>> getGameList(int consoleId) async => const [];
}
