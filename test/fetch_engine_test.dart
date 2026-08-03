import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/fetch_engine.dart';

void main() {
  test('emits a matched result when lookup returns a game id', () async {
    final results = <FetchResult>[];
    final engine = FetchEngine(
      hash: (path) async => 'h-$path',
      lookupGameId: (md5) async => 55,
      onResult: (r) async => results.add(r),
    );

    await engine.run(['/x/a.nes']);

    expect(results.single.matched, isTrue);
    expect(results.single.gameId, 55);
    expect(results.single.md5, 'h-/x/a.nes');
  });

  test('emits a no-match result when lookup returns null', () async {
    final results = <FetchResult>[];
    final engine = FetchEngine(
      hash: (path) async => 'h-$path',
      lookupGameId: (md5) async => null,
      onResult: (r) async => results.add(r),
    );

    await engine.run(['/x/a.nes']);

    expect(results.single.noMatch, isTrue);
    expect(results.single.matched, isFalse);
  });

  test('records a hash failure as unmatched, not no-match', () async {
    final results = <FetchResult>[];
    final engine = FetchEngine(
      hash: (path) async => null,
      lookupGameId: (md5) async => 1,
      onResult: (r) async => results.add(r),
    );

    await engine.run(['/x/a.nes']);

    expect(results.single.md5, isNull);
    expect(results.single.matched, isFalse);
    expect(results.single.noMatch, isFalse);
  });

  // Cancel has to land inside the per-folder loop: a system folder can hold
  // thousands of ROMs, so waiting for the whole list is the same as no cancel.
  test('stops as soon as isCancelled turns true', () async {
    final seen = <String>[];
    var cancelled = false;
    final engine = FetchEngine(
      hash: (path) async => 'h-$path',
      lookupGameId: (md5) async => 7,
      onResult: (r) async {
        seen.add(r.filePath);
        cancelled = true; // user hits Cancel while the first file is in flight
      },
      isCancelled: () => cancelled,
    );

    await engine.run(['/x/a.nes', '/x/b.nes', '/x/c.nes']);

    expect(seen, ['/x/a.nes']);
  });

  test('processes every file in order', () async {
    final seen = <String>[];
    final engine = FetchEngine(
      hash: (path) async => 'h-$path',
      lookupGameId: (md5) async => 7,
      onResult: (r) async => seen.add(r.filePath),
    );

    await engine.run(['/x/a.nes', '/x/b.nes']);

    expect(seen, ['/x/a.nes', '/x/b.nes']);
  });
}
