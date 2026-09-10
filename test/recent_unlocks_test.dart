import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rarm/services/ra_service.dart';
import 'package:rarm/services/recent_unlocks.dart';

RecentUnlock _u(String title, {DateTime? date}) => RecentUnlock(
      title: title,
      gameTitle: 'Game',
      badgeName: '123',
      points: 5,
      hardcore: true,
      date: date,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('caches the fetched list and serves it without refetching', () async {
    var calls = 0;
    Future<List<RecentUnlock>> fetch() async {
      calls++;
      return [_u('A', date: DateTime(2026, 1, 1))];
    }

    final t0 = DateTime(2026, 6, 1, 12);
    final first = await loadRecentUnlocks(now: t0, fetch: fetch);
    expect(first.single.title, 'A');
    expect(calls, 1);

    // Within the TTL the cache answers, so no second network call happens.
    final second = await loadRecentUnlocks(
        now: t0.add(const Duration(hours: 1)), fetch: fetch);
    expect(second.single.title, 'A');
    expect(calls, 1);
  });

  test('refetches once the cache is older than the TTL', () async {
    var calls = 0;
    Future<List<RecentUnlock>> fetch() async {
      calls++;
      return [_u('call$calls')];
    }

    final t0 = DateTime(2026, 6, 1, 12);
    const ttl = Duration(hours: 6);
    await loadRecentUnlocks(now: t0, ttl: ttl, fetch: fetch);
    final fresh = await loadRecentUnlocks(
        now: t0.add(const Duration(hours: 7)), ttl: ttl, fetch: fetch);
    expect(calls, 2);
    expect(fresh.single.title, 'call2');
  });

  test('serves the stale cache when a refetch fails', () async {
    final t0 = DateTime(2026, 6, 1, 12);
    await loadRecentUnlocks(
        now: t0, fetch: () async => [_u('cached', date: DateTime(2026, 1, 1))]);

    final result = await loadRecentUnlocks(
      now: t0.add(const Duration(days: 1)),
      fetch: () async => throw Exception('network down'),
    );
    expect(result.single.title, 'cached');
  });

  test('rethrows when a fetch fails and no cache exists', () async {
    expect(
      () => loadRecentUnlocks(fetch: () async => throw Exception('boom')),
      throwsA(isA<Exception>()),
    );
  });

  test('sorts unlocks newest first', () async {
    final unlocks = await loadRecentUnlocks(
      now: DateTime(2026, 6, 1),
      fetch: () async => [
        _u('old', date: DateTime(2020, 1, 1)),
        _u('new', date: DateTime(2025, 1, 1)),
      ],
    );
    expect(unlocks.map((u) => u.title).toList(), ['new', 'old']);
  });
}
