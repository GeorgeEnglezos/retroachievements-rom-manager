import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/scraped_game.dart';
import '../log_service.dart';
import 'rom_path_key.dart';

/// Path-keyed store of imported [ScrapedGame]s (one JSON file). Separate from RA
/// persistence. Keys are normalized+lowercased ROM paths so lookups survive case
/// differences. Pass [baseDir] in tests.
class ScrapedStore {
  ScrapedStore({Directory? baseDir}) : _baseDir = baseDir;

  /// App-wide shared store; tests build their own with a [baseDir].
  static final ScrapedStore instance = ScrapedStore();

  final Directory? _baseDir;

  final Map<String, ScrapedGame> _mem = {};
  bool _loaded = false;

  Future<File> _file() async {
    final base = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'data'));
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'scraped.json'));
  }

  /// Loads the file into memory once. Safe to call repeatedly.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final e in data.entries) {
        _mem[e.key] =
            ScrapedGame.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
    } catch (e) {
      LogService.error('ScrapedStore', 'load failed', err: e);
    }
  }

  /// Imported data for a ROM path, or null. Call [load] first.
  ScrapedGame? get(String romPath) => _mem[romPathKey(romPath)];

  /// Puts [g] straight into memory, for widget tests to seed the shared
  /// [instance] without touching path_provider or disk. Not for app code.
  @visibleForTesting
  void seed(ScrapedGame g) => _mem[romPathKey(g.romPath)] = g;

  /// Empties the shared [instance] so seeds don't leak between test cases.
  @visibleForTesting
  void resetForTest() {
    _mem.clear();
    _loaded = false;
  }

  /// Merges [games] in and persists. Loads first so existing entries survive.
  Future<void> putAll(Iterable<ScrapedGame> games) async {
    await load();
    for (final g in games) {
      _mem[romPathKey(g.romPath)] = g;
    }
    try {
      final f = await _file();
      await f.writeAsString(
          jsonEncode({for (final e in _mem.entries) e.key: e.value.toJson()}));
    } catch (e) {
      LogService.error('ScrapedStore', 'write failed', err: e);
    }
  }
}
