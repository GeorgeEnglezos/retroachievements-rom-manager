import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/android_emulators.dart';
import 'package:rarm/services/emulator_finder.dart';
import 'package:rarm/services/emulator_store.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('emu_finder'));
  tearDown(() => root.deleteSync(recursive: true));

  // Creates an empty file at [relative], parent folders included.
  File touch(String relative) {
    final f = File(p.join(root.path, p.joinAll(relative.split('/'))));
    f.parent.createSync(recursive: true);
    return f..writeAsStringSync('');
  }

  test('finds one emulator per known kind under the folder', () async {
    touch('RetroArch/retroarch.exe');
    touch('PCSX2/bin/pcsx2-qt.exe');
    touch('Dolphin/DolphinQt.exe');

    final found = await findEmulators(root);

    expect(found.map((e) => e.kindId).toSet(),
        {'retroarch', 'pcsx2', 'dolphin'});
    expect(found.firstWhere((e) => e.kindId == 'retroarch').name, 'RetroArch');
    expect(found.map((e) => e.id).toSet().length, found.length); // unique ids
  });

  test('ignores non-executables that match a kind pattern', () async {
    // 'retroarch' is an unanchored pattern, so its config and log files sit
    // right next to the exe and would match on name alone.
    touch('RetroArch/retroarch.cfg');
    touch('RetroArch/retroarch.log');

    expect(await findEmulators(root), isEmpty);
  });

  test('ignores executables that match no kind', () async {
    touch('Tools/7zip.exe');

    expect(await findEmulators(root), isEmpty);
  });

  test('the shallowest copy of a kind wins', () async {
    touch('Dolphin/backups/old/Dolphin.exe');
    touch('Dolphin/Dolphin.exe');

    final found = await findEmulators(root);

    expect(found, hasLength(1));
    expect(p.basename(p.dirname(found.single.exePath)), 'Dolphin');
  });

  test('skips kinds the user already added', () async {
    touch('RetroArch/retroarch.exe');
    touch('PCSX2/pcsx2.exe');

    final found = await findEmulators(root, existing: [
      Emulator(
          id: '1',
          name: 'RetroArch',
          exePath: r'D:\RetroArch\retroarch.exe',
          kindId: 'retroarch'),
    ]);

    expect(found.map((e) => e.kindId), ['pcsx2']);
  });

  test('missing folder returns nothing instead of throwing', () async {
    expect(await findEmulators(Directory(p.join(root.path, 'nope'))), isEmpty);
  });

  group('shortcuts', () {
    // Stands in for FileActions.resolveShortcuts (Windows WScript.Shell), which
    // can't run on Linux CI: maps each .lnk path to a fixed target.
    Future<Map<String, String>> Function(List<String>) resolver(
            Map<String, String> byName) =>
        (paths) async => {
              for (final path in paths)
                if (byName[p.basename(path)] != null)
                  path: byName[p.basename(path)]!,
            };

    test('resolves a .lnk to its target exe and detects the kind', () async {
      touch('Dolphin (GC-Wii).lnk');

      final found = await findEmulators(root,
          resolveShortcuts: resolver(
              {'Dolphin (GC-Wii).lnk': r'C:\Emu\Dolphin-x64\Dolphin.exe'}));

      expect(found.single.kindId, 'dolphin');
      // The stored path is the real target, not the shortcut.
      expect(found.single.exePath, r'C:\Emu\Dolphin-x64\Dolphin.exe');
    });

    test('ignores shortcuts whose target is a generic launcher', () async {
      // EmuDeck Start-Menu shortcuts point at powershell.exe running a .ps1.
      touch('dolphin.lnk');

      final found = await findEmulators(root,
          resolveShortcuts: resolver(
              {'dolphin.lnk': r'C:\Windows\System32\powershell.exe'}));

      expect(found, isEmpty);
    });

    test('ignores a shortcut that does not resolve', () async {
      touch('broken.lnk');

      expect(await findEmulators(root, resolveShortcuts: resolver({})), isEmpty);
    });
  });

  group('android', () {
    InstalledApp app(String package, String label) =>
        InstalledApp(package: package, label: label, known: true);

    test('maps recognised packages to kinds and keeps the app label', () {
      final found = emulatorsFromApps([
        app('com.retroarch', 'RetroArch'),
        app('org.ppsspp.ppsspp', 'PPSSPP'),
      ]);

      expect(found.map((e) => e.kindId), ['retroarch', 'ppsspp']);
      expect(found.first.name, 'RetroArch');
      // Android launches by package, so that's what exePath carries.
      expect(found.first.exePath, 'com.retroarch');
      expect(found.map((e) => e.id).toSet().length, 2); // unique ids
    });

    test('skips apps that are not known emulators', () {
      expect(emulatorsFromApps([app('com.whatsapp', 'WhatsApp')]), isEmpty);
    });

    test('takes one app per kind', () {
      final found = emulatorsFromApps([
        app('com.retroarch', 'RetroArch'),
        app('com.retroarch.aarch64', 'RetroArch (AArch64)'),
      ]);

      expect(found, hasLength(1));
      expect(found.single.name, 'RetroArch');
    });

    test('skips kinds the user already added', () {
      final found = emulatorsFromApps([
        app('com.retroarch', 'RetroArch'),
        app('org.dolphinemu.dolphinemu', 'Dolphin'),
      ], existing: [
        Emulator(
            id: '1',
            name: 'RetroArch',
            exePath: 'com.retroarch',
            kindId: 'retroarch'),
      ]);

      expect(found.map((e) => e.kindId), ['dolphin']);
    });
  });
}
