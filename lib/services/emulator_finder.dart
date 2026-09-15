import 'dart:io';

import 'package:path/path.dart' as p;

import 'android_emulators.dart';
import 'emulator_catalog.dart';
import 'emulator_store.dart';
import 'file_actions.dart';

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
  Future<Map<String, String>> Function(List<String>) resolveShortcuts =
      FileActions.resolveShortcuts,
}) async {
  if (!await root.exists()) return [];
  final taken = {for (final e in existing) e.kindId};
  final best = <String, String>{}; // kind id -> exe path
  final shortcuts = <String>[]; // .lnk paths, resolved after the walk
  var seen = 0;

  void consider(String exePath) {
    final kindId = EmulatorCatalog.detectKind(exePath);
    if (kindId == EmulatorCatalog.customKindId || taken.contains(kindId)) return;
    final current = best[kindId];
    if (current == null || _depth(exePath) < _depth(current)) {
      best[kindId] = exePath;
    }
  }

  try {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // ponytail: a flat file cap rather than a depth limit, so pointing this
      // at a whole drive still finishes. Raise it if real layouts hit it.
      if (++seen > maxFiles) break;
      final ext = p.windows.extension(entity.path).toLowerCase();
      if (ext == '.lnk') {
        shortcuts.add(entity.path);
      } else if (_exeExtensions.contains(ext)) {
        consider(entity.path);
      }
    }
  } on FileSystemException {
    // Permission error, or the folder went away mid-walk: keep what we found.
  }

  // Windows shortcuts (e.g. an EmuDeck folder of .lnk files) resolve to the real
  // exe elsewhere; store that target so launching works unchanged. Generic
  // launchers (a .ps1 behind powershell.exe) fall out via detectKind. Depth for
  // the shallowest-wins tiebreak comes from the target, not the .lnk — only
  // matters when one kind shows up as both a direct exe and a shortcut, rare.
  if (shortcuts.isNotEmpty) {
    final targets = await resolveShortcuts(shortcuts);
    for (final lnk in shortcuts) {
      final target = targets[lnk];
      if (target != null &&
          _exeExtensions
              .contains(p.windows.extension(target).toLowerCase())) {
        consider(target);
      }
    }
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
