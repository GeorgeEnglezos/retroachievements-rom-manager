import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';
import 'ra_service.dart';

/// Per-console `GetGameList` cache: offline md5->gameId and gameId->info
/// lookups so a rescan needs no network. Pass [baseDir] in tests.
class RaCache {
  RaCache({Directory? baseDir}) : _baseDir = baseDir;

  final Directory? _baseDir;
  // consoleId -> (md5 -> gameId), built once per console on first access.
  final Map<int, Map<String, int>> _hashIndex = {};
  // consoleId -> (gameId -> entry).
  final Map<int, Map<int, RaGameListEntry>> _byGame = {};
  final Map<int, Future<void>> _loading = {};

  Future<Directory> _dir() async {
    final base = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'data', 'ra_cache'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(int consoleId) async =>
      File(p.join((await _dir()).path, 'console_$consoleId.json'));

  Future<void> _ensureLoaded(int consoleId) =>
      _loading.putIfAbsent(consoleId, () => _load(consoleId));

  Future<void> _load(int consoleId) async {
    final f = await _file(consoleId);
    if (!await f.exists()) return;
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final entries = [
        for (final g in (data['games'] as List? ?? const []))
          RaGameListEntry.fromJson(Map<String, dynamic>.from(g as Map)),
      ];
      _index(consoleId, entries);
    } catch (e) {
      LogService.error('RaCache', 'parse console_$consoleId failed', err: e);
    }
  }

  void _index(int consoleId, List<RaGameListEntry> entries) {
    final hashMap = <String, int>{};
    final gameMap = <int, RaGameListEntry>{};
    for (final e in entries) {
      gameMap[e.gameId] = e;
      for (final h in e.hashes) {
        hashMap[h] = e.gameId;
      }
    }
    _hashIndex[consoleId] = hashMap;
    _byGame[consoleId] = gameMap;
  }

  /// Persists [entries] for [consoleId] and refreshes the in-memory maps.
  ///
  /// Hashes learned from the `dorequest` fallback are carried over: GetGameList
  /// ships ~1 hash per game, so a plain overwrite would drop every secondary
  /// dump the user already matched and send the next scan back to the network.
  /// A game absent from [entries] is dropped, learned hashes included.
  Future<void> storeConsole(int consoleId, List<RaGameListEntry> entries) async {
    await _ensureLoaded(consoleId); // merge against what's already on disk
    final known = _byGame[consoleId] ?? const {};
    final merged = [
      for (final e in entries) _withLearnedHashes(e, known[e.gameId]),
    ];
    _loading[consoleId] = Future.value();
    _index(consoleId, merged);
    await _write(consoleId, merged);
  }

  /// [fresh] plus any hash the old entry carried that RA's list doesn't.
  RaGameListEntry _withLearnedHashes(
      RaGameListEntry fresh, RaGameListEntry? old) {
    if (old == null) return fresh;
    final extra = [
      for (final h in old.hashes)
        if (!fresh.hashes.contains(h)) h,
    ];
    return extra.isEmpty
        ? fresh
        : fresh.copyWith(hashes: [...fresh.hashes, ...extra]);
  }

  Future<void> _write(int consoleId, Iterable<RaGameListEntry> entries) async {
    final f = await _file(consoleId);
    await f.writeAsString(jsonEncode({
      // Written for future TTL/debugging; no reader today.
      'fetchedAt': DateTime.now().toIso8601String(),
      'games': [for (final e in entries) e.toJson()],
    }));
  }

  Future<bool> hasConsole(int consoleId) async {
    await _ensureLoaded(consoleId);
    return _byGame.containsKey(consoleId);
  }

  /// Offline hash match: gameId for [md5] on [consoleId], or null.
  Future<int?> lookupGameId(String md5, int consoleId) async {
    await _ensureLoaded(consoleId);
    return _hashIndex[consoleId]?[md5.toLowerCase()];
  }

  /// Basic list-row info for a matched game, or null if not cached.
  Future<RaGameListEntry?> entryForGame(int gameId, int consoleId) async {
    await _ensureLoaded(consoleId);
    return _byGame[consoleId]?[gameId];
  }

  /// Fetches the console's list from RA and stores it.
  Future<void> refreshConsole(int consoleId, RaService service) async {
    final entries = await service.getGameList(consoleId);
    await storeConsole(consoleId, entries);
  }

  /// Ensures the console list is cached, then matches the hash. Null means RA
  /// genuinely knows no game for it; a failed lookup (offline, timeout) throws
  /// instead, because a swallowed failure would be persisted as a confirmed
  /// no-match and every later unfetched-only scan would skip that ROM.
  Future<int?> resolveGameId(
      RaService service, int? consoleId, String md5) async {
    if (consoleId == null) return null;
    if (!await hasConsole(consoleId)) {
      try {
        await refreshConsole(consoleId, service);
      } catch (e) {
        LogService.error('RaCache/resolve', 'console $consoleId: $e');
        // A failed list fetch shouldn't block the online dorequest lookup.
      }
    }
    final offline = await lookupGameId(md5, consoleId);
    if (offline != null) return offline;

    // GetGameList has ~1 hash per game; secondary dumps miss offline.
    // Fall back to dorequest, caching hits in memory.
    try {
      final online = await service.getGameIdByHash(md5);
      if (online != null) {
        (_hashIndex[consoleId] ??= {})[md5.toLowerCase()] = online;
        await _persistOnlineHit(consoleId, online, md5.toLowerCase());
      }
      return online;
    } catch (e) {
      LogService.error('RaCache/resolve', 'online fallback $md5: $e');
      rethrow;
    }
  }

  /// Persists a dorequest hit into the console file so restarts stay offline.
  /// Memory-only when the game isn't in the cached list.
  Future<void> _persistOnlineHit(int consoleId, int gameId, String md5) async {
    final entry = _byGame[consoleId]?[gameId];
    if (entry == null || entry.hashes.contains(md5)) return;
    _byGame[consoleId]![gameId] = entry.copyWith(hashes: [...entry.hashes, md5]);
    try {
      await _write(consoleId, _byGame[consoleId]!.values);
    } catch (e) {
      LogService.error('RaCache/persistHit', 'console $consoleId: $e');
    }
  }
}
