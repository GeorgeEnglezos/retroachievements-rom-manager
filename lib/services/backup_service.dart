import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pref_keys.dart';

/// Support-dir folders left out of a backup. Session logs are noise in one,
/// and the current one is held open on Windows.
const _keptDirs = {'logs'};

/// The prefs snapshot's name inside the zip. A restore requires it, so it
/// doubles as the marker that says a chosen zip really is a RARM backup.
const _prefsEntry = 'prefs.json';

/// Backs up and restores everything the app has written: the whole
/// app-support directory (scans, imported metadata, cached artwork and icons)
/// plus a `prefs.json` snapshot of settings. Deleting it is [DataWipe]'s job.
/// Pass [baseDir] in tests.
///
/// The API key is never in a backup. It lives in [SecretStore], and the one
/// path that does put it in prefs (a Linux box with no secret service) is
/// filtered out here, so a backup file is safe to copy around.
class BackupService {
  final Directory? baseDir;
  const BackupService({this.baseDir});

  Future<Directory> _base() async =>
      baseDir ?? await getApplicationSupportDirectory();

  /// Writes a backup zip to [outPath]. Files are streamed in and out of the
  /// archive one at a time, on a background isolate: a cached-artwork folder
  /// runs to hundreds of MB, which neither fits in memory nor belongs on the
  /// UI isolate. Throws on failure so the caller can report it.
  Future<void> create(String outPath) async {
    final base = await _base();
    final prefs = await SharedPreferences.getInstance();
    final snapshot = jsonEncode({
      for (final k in prefs.getKeys())
        if (k != PrefKeys.raApiKey) k: prefs.get(k),
    });
    final basePath = base.path;
    await Isolate.run(() => _zip(basePath, outPath, snapshot));
  }

  /// Restores a backup zip from [inPath], replacing current data and settings.
  /// Throws [FormatException] if the zip holds no valid prefs snapshot. Any
  /// failure leaves current data untouched. The app should be restarted
  /// afterwards so in-memory caches reload.
  Future<void> restore(String inPath) async {
    final base = await _base();
    final basePath = base.path;
    final snapshot = await Isolate.run(() => _unzip(inPath, basePath));
    await _restorePrefs(snapshot);
  }

  // Runs via Isolate.run: file IO plus zip compression, off the UI isolate.
  // Every add is awaited; the encoder reads each file asynchronously, so a
  // fire-and-forget add races the close and drops the entry.
  static Future<void> _zip(
      String basePath, String outPath, String prefsJson) async {
    final encoder = ZipFileEncoder()..create(outPath);
    try {
      final base = Directory(basePath);
      if (base.existsSync()) {
        for (final f in base.listSync(recursive: true, followLinks: false)) {
          if (f is! File) continue;
          final rel = p.relative(f.path, from: basePath).replaceAll('\\', '/');
          if (_keptDirs.contains(rel.split('/').first)) continue;
          await encoder.addFile(f, rel);
        }
      }
      encoder.addArchiveFile(ArchiveFile.string(_prefsEntry, prefsJson));
    } finally {
      await encoder.close();
    }
  }

  /// Extracts [inPath] into a sibling staging dir, then swaps it in over
  /// [basePath] and returns the decoded prefs snapshot. A missing or
  /// malformed snapshot, or a failed extract, throws before [basePath] is
  /// touched.
  static Map<String, dynamic> _unzip(String inPath, String basePath) {
    final staging = _freshDir('$basePath.restore');
    final input = InputFileStream(inPath);
    try {
      final archive = ZipDecoder().decodeStream(input);
      final snapshotEntry = archive.files
          .where((e) => e.isFile && e.name == _prefsEntry)
          .firstOrNull;
      if (snapshotEntry == null) {
        throw const FormatException('Not a RARM backup: no prefs.json');
      }
      final snapshot =
          jsonDecode(utf8.decode(snapshotEntry.readBytes() ?? const []));
      if (snapshot is! Map<String, dynamic>) {
        throw const FormatException('Not a RARM backup: bad prefs.json');
      }

      for (final entry in archive) {
        if (!entry.isFile || entry.name == _prefsEntry) continue;
        final out = File(p.normalize(p.join(staging.path, entry.name)));
        // Zip Slip guard: a name like `data/../../x` normalises outside base.
        if (!p.isWithin(staging.path, out.path)) continue;
        final top = p.split(p.relative(out.path, from: staging.path)).first;
        if (_keptDirs.contains(top)) continue;
        out.parent.createSync(recursive: true);
        final sink = OutputFileStream(out.path);
        try {
          entry.writeContent(sink);
        } finally {
          sink.closeSync();
        }
      }
      _swapIn(staging.path, basePath);
      return snapshot;
    } finally {
      input.closeSync();
      if (staging.existsSync()) staging.deleteSync(recursive: true);
    }
  }

  /// Replaces [basePath]'s contents (bar [_keptDirs]) with [stagingPath]'s.
  /// Replace, don't merge: a file the backup doesn't know about would
  /// otherwise survive as a ghost. Same-volume renames, rolled back if one
  /// fails so the old data comes back whole.
  static void _swapIn(String stagingPath, String basePath) {
    final old = _freshDir('$basePath.old');
    final base = Directory(basePath)..createSync(recursive: true);
    final movedOut = <String>[];
    final movedIn = <String>[];
    try {
      for (final e in base.listSync(followLinks: false)) {
        final name = p.basename(e.path);
        if (_keptDirs.contains(name)) continue;
        e.renameSync(p.join(old.path, name));
        movedOut.add(name);
      }
      for (final e in Directory(stagingPath).listSync(followLinks: false)) {
        final name = p.basename(e.path);
        e.renameSync(p.join(basePath, name));
        movedIn.add(name);
      }
    } catch (_) {
      for (final name in movedIn) {
        _entity(p.join(basePath, name)).renameSync(p.join(stagingPath, name));
      }
      for (final name in movedOut) {
        _entity(p.join(old.path, name)).renameSync(p.join(basePath, name));
      }
      old.deleteSync(recursive: true);
      rethrow;
    }
    old.deleteSync(recursive: true);
  }

  static FileSystemEntity _entity(String path) =>
      FileSystemEntity.isDirectorySync(path) ? Directory(path) : File(path);

  /// An empty dir at [path], clearing leftovers of an interrupted restore.
  static Directory _freshDir(String path) {
    final d = Directory(path);
    if (d.existsSync()) d.deleteSync(recursive: true);
    return d..createSync(recursive: true);
  }

  /// Replaces every pref with the snapshot's, keeping the API key: it was
  /// never in the backup, so applying one must not sign the user out.
  Future<void> _restorePrefs(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(PrefKeys.raApiKey);
    await prefs.clear();
    if (apiKey != null) await prefs.setString(PrefKeys.raApiKey, apiKey);
    for (final e in map.entries) {
      if (e.key == PrefKeys.raApiKey) continue;
      final v = e.value;
      // A prefs double that happens to be whole (5.0) round-trips
      // through JSON as an int. Harmless here; no double prefs exist.
      if (v is bool) {
        await prefs.setBool(e.key, v);
      } else if (v is int) {
        await prefs.setInt(e.key, v);
      } else if (v is double) {
        await prefs.setDouble(e.key, v);
      } else if (v is String) {
        await prefs.setString(e.key, v);
      } else if (v is List) {
        await prefs.setStringList(e.key, v.map((x) => x.toString()).toList());
      }
    }
  }
}
