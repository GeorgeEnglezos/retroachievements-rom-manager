import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/game_entry.dart';
import '../models/home_index.dart' show SystemSummary, SearchIndexEntry;
import '../models/system_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_actions.dart';
import 'home_index_builder.dart';
import 'log_service.dart';
import 'pref_keys.dart';
import 'scan_settings.dart';

/// Single source of truth for scanned data: all systems in memory, home grid
/// and search derived from it, one `systems/<systemId>.json` per system.
/// Pass [baseDir] in tests.
class Library extends ChangeNotifier {
  Library({Directory? baseDir}) : _baseDir = baseDir;

  /// App-wide shared store; tests build their own with a [baseDir].
  static final Library instance = Library();

  final Directory? _baseDir;
  final Map<String, SystemData> _byId = {};

  // Systems whose folder is currently gone (deleted, or a drive not mounted),
  // normalized. See [refreshMissingSystems]; the derived views all hide these.
  final Set<String> _missingSystemPaths = {};
  Future<void>? _initFuture;
  Directory? _systemsDirCache;

  // Serializes mutations so concurrent saves can't double-assign ids.
  Future<void> _writeLock = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _writeLock.then((_) => action());
    _writeLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Directory> _systemsDir() async {
    if (_systemsDirCache != null) return _systemsDirCache!;
    final base = _baseDir ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'data', 'systems'));
    await dir.create(recursive: true);
    return _systemsDirCache = dir;
  }

  String _norm(String path) => p.normalize(path).toLowerCase();

  String _idForPath(String path) =>
      sha1.convert(utf8.encode(_norm(path))).toString();

  SystemData? _findByPath(String path) {
    final norm = _norm(path);
    for (final d in _byId.values) {
      if (_norm(d.systemPath) == norm) return d;
    }
    return null;
  }

  /// Loads every system file into memory once. Safe to call repeatedly and
  /// concurrently; the load body runs at most once.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    final dir = await _systemsDir();
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        var data = SystemData.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>);
        // Migration: legacy files lack systemId, adopt the filename stem.
        if (data.systemId.isEmpty) {
          data = data.copyWith(systemId: p.basenameWithoutExtension(f.path));
          await f.writeAsString(jsonEncode(data.toJson()));
        }
        _byId[data.systemId] = data;
      } catch (e) {
        LogService.error('Library/init', 'Failed to parse ${f.path}', err: e);
      }
    }
    // Migration: home.json is now a derived view; delete the stale duplicate.
    final home = File(p.join(dir.parent.path, 'home.json'));
    if (await home.exists()) await home.delete();
  }

  /// Full data for the folder at [path], or empty data if never scanned.
  Future<SystemData> load(String path) async {
    await init();
    return _findByPath(path) ??
        SystemData(
          systemId: '',
          systemPath: path,
          games: const [],
          dismissedDuplicatePairs: <String>{},
          consoleId: null,
        );
  }

  /// Writes one system file and updates memory; assigns a stable [systemId]
  /// on first save. Returns the stored data.
  Future<SystemData> save(SystemData data) async {
    await init();
    return _locked(() async {
      var d = data;
      if (d.systemId.isEmpty) {
        d = d.copyWith(
            systemId: _findByPath(d.systemPath)?.systemId ??
                _idForPath(d.systemPath));
      }
      _byId[d.systemId] = d;
      final file =
          File(p.join((await _systemsDir()).path, '${d.systemId}.json'));
      await file.writeAsString(jsonEncode(d.toJson()));
      notifyListeners();
      return d;
    });
  }

  /// Recycles the ROM file at [path] and, once it's gone, drops its entry
  /// from the owning system file, so derived views (home, search, cleanup)
  /// don't resurrect a deleted game. True when the file no longer exists.
  /// [recycle] is injectable for tests only.
  Future<bool> deleteRom(String path,
      {Future<bool> Function(String) recycle =
          FileActions.moveToRecycleBin}) async {
    final gone = await recycle(path);
    if (gone) await removeGame(path);
    return gone;
  }

  /// Removes the game entry for [path] from every system file holding it;
  /// overlapping system roots (parent + subfolder) can both list one file.
  Future<void> removeGame(String path) async {
    await init();
    final norm = _norm(path);
    return _locked(() async {
      var changed = false;
      for (final d in _byId.values.toList()) {
        final games = [
          for (final g in d.games)
            if (_norm(g.filePath) != norm) g
        ];
        if (games.length == d.games.length) continue;
        final nd = d.copyWith(games: games);
        _byId[nd.systemId] = nd;
        final file =
            File(p.join((await _systemsDir()).path, '${nd.systemId}.json'));
        await file.writeAsString(jsonEncode(nd.toJson()));
        changed = true;
      }
      if (changed) notifyListeners();
    });
  }

  Future<void> remove(String path) async {
    await init();
    return _locked(() async {
      final d = _findByPath(path);
      if (d == null) return;
      _byId.remove(d.systemId);
      final file =
          File(p.join((await _systemsDir()).path, '${d.systemId}.json'));
      if (await file.exists()) await file.delete();
      notifyListeners();
    });
  }

  /// Deletes every system file and empties memory.
  Future<void> clear() async {
    await init();
    return _locked(() async {
      _byId.clear();
      final dir = await _systemsDir();
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.json')) await f.delete();
      }
      notifyListeners();
    });
  }

  // Derived views recomputed on read; trivial at a few thousand
  // games. Cache per-notify if a profiler ever flags it.

  /// The live exclude/ignore filters, loaded once per derived-view read so a
  /// settings change takes effect app-wide without a rescan (mirrors the
  /// Storage tab, which filters at display time).
  Future<_ScanFilters> _scanFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final root = prefs.getString(PrefKeys.lastFolder);
    return _ScanFilters(
      (await ScanSettings.excludedFiles()).map((e) => e.toLowerCase()).toSet(),
      (await ScanSettings.ignoredFolders()).map((e) => e.toLowerCase()).toSet(),
      root == null || root.isEmpty ? null : _norm(root),
    );
  }

  /// Whether the system at [systemPath] is hidden from every derived view:
  /// ignored, its folder is gone, or it's stale from a previous library root
  /// (not a direct child of the current one). Null root means no root is set
  /// yet, so nothing is scoped out.
  bool _hidden(String systemPath, _ScanFilters f) =>
      isSystemMissing(systemPath) ||
      ScanSettings.isFolderIgnored(systemPath, f.ignored) ||
      (f.root != null && _norm(p.dirname(systemPath)) != f.root);

  /// Home-grid summaries, computed from in-memory system data. The single
  /// source of truth for "which systems exist": ignored, missing, out-of-root,
  /// and empty (no games left after the exclude/ignore filter) systems all drop
  /// out, so every view built on this hides exactly what the home grid hides.
  Future<List<SystemSummary>> summaries() async {
    await init();
    final f = await _scanFilters();
    return [
      for (final d in _byId.values)
        if (!_hidden(d.systemPath, f))
          buildSummary(d,
              systemId: d.systemId,
              name: p.basename(d.systemPath),
              consoleId: d.consoleId,
              keep: f.keepFor(d.systemPath)),
    ].where((s) => s.totalGames > 0).toList();
  }

  /// Flat search rows, computed from in-memory system data. Excluded/ignored
  /// games (and whole ignored or missing systems) never surface in search.
  Future<List<SearchIndexEntry>> searchIndex() async {
    await init();
    final f = await _scanFilters();
    return [
      for (final d in _byId.values)
        if (!_hidden(d.systemPath, f))
          ...buildSearchRows(d,
              systemName: p.basename(d.systemPath),
              keep: f.keepFor(d.systemPath)),
    ];
  }

  /// One system's games with the live exclude/ignore filters applied, so a
  /// derived view that needs the raw entries (not a summary or a search row)
  /// hides exactly what [summaries] and [searchIndex] hide. Empty for an
  /// ignored or missing system, or a path that was never scanned.
  Future<List<GameEntry>> gamesFor(String systemPath) async {
    await init();
    final f = await _scanFilters();
    if (_hidden(systemPath, f)) return const [];
    final keep = f.keepFor(systemPath);
    return [
      for (final g in (await load(systemPath)).games)
        if (keep(g)) g
    ];
  }

  /// Re-checks which system folders still exist and hides the ones that don't
  /// from every derived view. Their data is deliberately kept, so a remounted
  /// drive comes back on the next check instead of needing a rescan.
  /// Notifies only when the answer changed. Safe to call unawaited.
  Future<void> refreshMissingSystems() async {
    await init();
    final gone = <String>{};
    // Snapshot: a save during the awaits would otherwise mutate _byId mid-loop.
    for (final d in _byId.values.toList()) {
      try {
        if (!await Directory(d.systemPath).exists()) gone.add(_norm(d.systemPath));
      } catch (e) {
        // A drive that errors on stat counts as present: hiding a system on a
        // transient IO error loses more than showing a stale one.
        LogService.error('Library/missingSystems', 'Cannot stat ${d.systemPath}',
            err: e);
      }
    }
    if (setEquals(gone, _missingSystemPaths)) return;
    _missingSystemPaths
      ..clear()
      ..addAll(gone);
    notifyListeners();
  }

  /// Whether [systemPath]'s folder was gone at the last [refreshMissingSystems].
  /// False before the first one: nothing is assumed missing until checked.
  bool isSystemMissing(String systemPath) =>
      _missingSystemPaths.contains(_norm(systemPath));

  /// Permanently deletes every system whose folder no longer exists. A manual
  /// cleanup for a moved or renamed library; the automatic path only hides
  /// missing systems ([refreshMissingSystems]) so a remounted drive returns.
  /// Returns how many systems were removed.
  Future<int> pruneMissingSystems() async {
    await init();
    return _locked(() async {
      final dir = await _systemsDir();
      var removed = 0;
      for (final d in _byId.values.toList()) {
        try {
          if (await Directory(d.systemPath).exists()) continue;
        } catch (_) {
          // An IO error (offline drive) counts as present, so a transient
          // failure never deletes data.
          continue;
        }
        _byId.remove(d.systemId);
        _missingSystemPaths.remove(_norm(d.systemPath));
        final file = File(p.join(dir.path, '${d.systemId}.json'));
        if (await file.exists()) await file.delete();
        removed++;
      }
      if (removed > 0) notifyListeners();
      return removed;
    });
  }

  /// Every scanned ROM's absolute file path across all systems. Used to match
  /// imported gamelist entries to real files.
  Future<Set<String>> allRomPaths() async {
    await init();
    return {
      for (final d in _byId.values)
        for (final g in d.games) g.filePath,
    };
  }

}

/// The live exclude/ignore sets (lowercased) plus a per-system predicate that
/// drops any game the user has excluded or that sits under an ignored subfolder.
class _ScanFilters {
  final Set<String> excluded;
  final Set<String> ignored;
  /// Current library root (normalized), or null when none is set.
  final String? root;
  const _ScanFilters(this.excluded, this.ignored, this.root);

  bool Function(GameEntry g) keepFor(String systemPath) => (g) =>
      !ScanSettings.isFileExcluded(g.filePath, excluded) &&
      !ScanSettings.isUnderIgnoredFolder(g.filePath, systemPath, ignored);
}
