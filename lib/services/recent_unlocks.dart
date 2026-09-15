import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'credentials.dart';
import 'log_service.dart';
import 'ra_service.dart';

/// Serve a cached unlocks list for this long before refetching. The panel is
/// read-only and a just-earned unlock can wait, so this spares a multi-year RA
/// payload on every Home open.
const _cacheTtl = Duration(hours: 6);
// Single-service key, so it stays private here (see pref_keys.dart convention).
const _cacheKey = 'recent_unlocks_cache';

/// The user's latest achievement unlocks, sorted newest first, capped at [max],
/// or empty when RA credentials aren't set. Shared by every Home surface
/// (dashboard + couch).
///
/// Cache-first: a cache younger than [ttl] is served without any network call.
/// A stale or missing cache triggers a refetch that is then cached. If the
/// refetch fails, a stale cache is served rather than throwing; only a failure
/// with no cache at all throws, so the caller can show its own error state.
///
/// Uses the earned-between endpoint over a wide window so it shows the player's
/// most recent unlocks even if they last played long ago (the recent-minutes
/// feed returns nothing for a dormant account).
/// ponytail: [years] back is a bounded window, not "all history"; a hardcore
/// account earns thousands, so this trades reach for payload. Widen it, or page
/// by year, if a very dormant account must still populate.
///
/// [now] and [fetch] are test seams; production passes neither.
Future<List<RecentUnlock>> loadRecentUnlocks({
  int max = 20,
  int years = 6,
  Duration ttl = _cacheTtl,
  DateTime? now,
  Future<List<RecentUnlock>> Function()? fetch,
}) async {
  final clock = now ?? DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  final cached = _readCache(prefs);

  if (cached != null && clock.difference(cached.$1) < ttl) {
    return cached.$2.take(max).toList();
  }

  var fetcher = fetch;
  if (fetcher == null) {
    final creds = await savedCredentials();
    if (creds == null) {
      LogService.debug('RecentUnlocks', 'no RA credentials; panel stays empty');
      return cached?.$2.take(max).toList() ?? const [];
    }
    fetcher = () => RaService(username: creds.$1, apiKey: creds.$2)
            .getAchievementsEarnedBetween(
          from: DateTime(clock.year - years, clock.month, clock.day),
          to: clock,
        );
  }

  try {
    final unlocks = await fetcher();
    // Sort by unlock date, newest first; unlocks with no date sink to the bottom.
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    unlocks.sort((a, b) => (b.date ?? epoch).compareTo(a.date ?? epoch));
    final capped = unlocks.take(max).toList();
    await _writeCache(prefs, clock, capped);
    return capped;
  } catch (e) {
    if (cached != null) {
      LogService.debug(
          'RecentUnlocks', 'refetch failed ($e); serving stale cache');
      return cached.$2.take(max).toList();
    }
    rethrow;
  }
}

/// (cachedAt, unlocks) from the persisted blob, or null when absent or corrupt.
(DateTime, List<RecentUnlock>)? _readCache(SharedPreferences prefs) {
  final raw = prefs.getString(_cacheKey);
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final at = DateTime.parse(map['cachedAt'] as String);
    final unlocks = [
      for (final e in map['unlocks'] as List<dynamic>)
        RecentUnlock.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return (at, unlocks);
  } catch (_) {
    return null; // Malformed or version-skewed blob: treat as no cache.
  }
}

Future<void> _writeCache(
    SharedPreferences prefs, DateTime at, List<RecentUnlock> unlocks) async {
  await prefs.setString(
    _cacheKey,
    jsonEncode({
      'cachedAt': at.toIso8601String(),
      'unlocks': [for (final u in unlocks) u.toJson()],
    }),
  );
}
