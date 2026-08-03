import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One archive member in flight: its zip path and raw bytes. Plain fields so it
/// crosses the isolate boundary.
typedef _Entry = ({String name, List<int> bytes});

/// Backs up/restores all user data as one `.zip`: `<support>/data/` plus a
/// `prefs.json` SharedPreferences snapshot. Pass [baseDir] in tests.
class BackupService {
  final Directory? baseDir;
  const BackupService({this.baseDir});

  Future<Directory> _base() async =>
      baseDir ?? await getApplicationSupportDirectory();

  /// Writes a backup zip to [outPath]. File reads are async and the zip is
  /// encoded on a background isolate so a large library doesn't freeze the UI.
  Future<void> create(String outPath) async {
    final base = await _base();
    final entries = <_Entry>[];

    final dataDir = Directory(p.join(base.path, 'data'));
    if (await dataDir.exists()) {
      await for (final f in dataDir.list(recursive: true)) {
        if (f is! File) continue;
        final rel = p.relative(f.path, from: base.path).replaceAll('\\', '/');
        entries.add((name: rel, bytes: await f.readAsBytes()));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final prefsMap = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    entries.add((name: 'prefs.json', bytes: utf8.encode(jsonEncode(prefsMap))));

    final zip = await Isolate.run(() => _encode(entries));
    await File(outPath).writeAsBytes(zip);
  }

  /// Restores a backup zip from [inPath], overwriting current data and prefs.
  /// The app should be restarted afterwards so in-memory caches reload. Decoding
  /// runs on a background isolate; entries that escape the base dir are rejected.
  Future<void> restore(String inPath) async {
    final base = await _base();
    final bytes = await File(inPath).readAsBytes();
    final entries = await Isolate.run(() => _decode(bytes));

    for (final entry in entries) {
      if (entry.name == 'prefs.json') {
        await _restorePrefs(utf8.decode(entry.bytes));
        continue;
      }
      // Only restore data/* paths; ignore anything else for safety.
      if (!entry.name.startsWith('data/')) continue;
      final out = File(p.normalize(p.join(base.path, entry.name)));
      // Zip Slip guard: a name like `data/../../x` normalises outside base.
      if (!p.isWithin(base.path, out.path)) continue;
      await out.parent.create(recursive: true);
      await out.writeAsBytes(entry.bytes);
    }
  }

  // CPU-bound zip work, run via Isolate.run so it stays off the UI isolate.
  static List<int> _encode(List<_Entry> entries) {
    final archive = Archive();
    for (final e in entries) {
      archive.addFile(ArchiveFile(e.name, e.bytes.length, e.bytes));
    }
    return ZipEncoder().encode(archive);
  }

  static List<_Entry> _decode(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return [
      for (final e in archive)
        if (e.isFile) (name: e.name, bytes: e.content as List<int>),
    ];
  }

  Future<void> _restorePrefs(String json) async {
    final map = jsonDecode(json) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    for (final e in map.entries) {
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
