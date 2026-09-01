import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_emulators.dart';
import 'emulator_catalog.dart';
import 'emulator_store.dart';

/// Extensions worth testing against the catalog patterns. Most patterns are
/// unanchored, so without this filter `retroarch` also matches the retroarch.cfg
/// and retroarch.log sitting beside the real exe.
const _exeExtensions = {'.exe', '.appimage'};

/// Emulators found under [root], ready to hand to [EmulatorStore.addEmulator]
/// (which connects their default systems). One per catalog kind; kinds already
/// in [existing] are skipped so a rescan doesn't duplicate them.
///
/// When a kind turns up more than once the shallowest path wins: an install's
/// real exe sits above its bundled or backed-up copies.
Future<List<Emulator>> findEmulators(
  Directory root, {
  List<Emulator> existing = const [],
  int maxFiles = 50000,
}) async {
  if (!await root.exists()) return [];
  final taken = {for (final e in existing) e.kindId};
  final best = <String, String>{}; // kind id -> exe path
  var seen = 0;

  try {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // ponytail: a flat file cap rather than a depth limit, so pointing this
      // at a whole drive still finishes. Raise it if real layouts hit it.
      if (++seen > maxFiles) break;
      if (!_exeExtensions
          .contains(p.windows.extension(entity.path).toLowerCase())) {
        continue;
      }
      final kindId = EmulatorCatalog.detectKind(entity.path);
      if (kindId == EmulatorCatalog.customKindId || taken.contains(kindId)) {
        continue;
      }
      final current = best[kindId];
      if (current == null || _depth(entity.path) < _depth(current)) {
        best[kindId] = entity.path;
      }
    }
  } on FileSystemException {
    // Permission error, or the folder went away mid-walk: keep what we found.
  }

  final stamp = DateTime.now().millisecondsSinceEpoch;
  return [
    for (final entry in best.entries)
      Emulator(
        // The kind is part of the id because a whole batch is created within
        // the same millisecond.
        id: '$stamp-${entry.key}',
        name: EmulatorCatalog.kindById(entry.key)?.name ?? entry.key,
        exePath: entry.value,
        kindId: entry.key,
      ),
  ];
}

// Windows context so a `C:\...` path splits correctly off-Windows too; it
// treats forward slashes as separators as well, so posix paths still work.
int _depth(String path) => p.windows.split(path).length;

/// The [apps] we recognise as emulators, ready to hand to
/// [EmulatorStore.addEmulator]. One per catalog kind (phones often carry both
/// com.retroarch and com.retroarch.aarch64), kinds already in [existing]
/// skipped. The app's own label is kept as the name so the list matches what
/// the launcher shows.
List<Emulator> emulatorsFromApps(
  List<InstalledApp> apps, {
  List<Emulator> existing = const [],
}) {
  final taken = {for (final e in existing) e.kindId};
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final found = <Emulator>[];
  for (final app in apps) {
    final kindId = EmulatorCatalog.detectKindFromPackage(app.package);
    if (kindId == EmulatorCatalog.customKindId || !taken.add(kindId)) continue;
    found.add(Emulator(
      id: '$stamp-$kindId',
      name: app.label,
      exePath: app.package, // Android stores the package here, not a path.
      kindId: kindId,
    ));
  }
  return found;
}
