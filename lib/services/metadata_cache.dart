import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/game_metadata.dart';
import 'log_service.dart';

/// Offline name->metadata cache for third-party providers, so rescans of
/// display-only systems need no network. One JSON file per (provider, console),
/// keyed by cleaned name. Pass [baseDir] in tests.
///
/// Hits only: misses are re-queried. GameEntry persistence already stops the
/// per-ROM re-fetch on rescan, so caching misses buys little.
class MetadataCache {
  MetadataCache({Directory? baseDir}) : _baseDir = baseDir;
  final Directory? _baseDir;

  // "providerId_consoleId" -> (cleanedName -> metadata)
  final Map<String, Map<String, GameMetadata>> _mem = {};
  final Map<String, Future<void>> _loading = {};

  String _key(String providerId, int consoleId) => '${providerId}_$consoleId';

  Future<Directory> _dir() async {
    final base = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'data', 'metadata_cache'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String key) async =>
      File(p.join((await _dir()).path, '$key.json'));

  Future<void> _ensureLoaded(String key) =>
      _loading.putIfAbsent(key, () => _load(key));

  Future<void> _load(String key) async {
    final f = await _file(key);
    if (!await f.exists()) return;
    try {
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _mem[key] = {
        for (final e in data.entries)
          e.key:
              GameMetadata.fromJson(Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (e) {
      LogService.error('MetadataCache', 'parse $key failed', err: e);
    }
  }

  /// Cached metadata for a cleaned name, or null.
  Future<GameMetadata?> get(
      String providerId, int consoleId, String cleanedName) async {
    final key = _key(providerId, consoleId);
    await _ensureLoaded(key);
    return _mem[key]?[cleanedName];
  }

  /// Stores [meta] for a cleaned name and persists the console file.
  Future<void> put(String providerId, int consoleId, String cleanedName,
      GameMetadata meta) async {
    final key = _key(providerId, consoleId);
    await _ensureLoaded(key);
    (_mem[key] ??= {})[cleanedName] = meta;
    try {
      final f = await _file(key);
      await f.writeAsString(jsonEncode({
        for (final e in _mem[key]!.entries) e.key: e.value.toJson(),
      }));
    } catch (e) {
      LogService.error('MetadataCache', 'write $key failed', err: e);
    }
  }
}
