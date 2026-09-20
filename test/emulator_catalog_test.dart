import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/emulator_catalog.dart';

void main() {
  group('detectKind', () {
    test('matches RetroArch by exe name', () {
      expect(EmulatorCatalog.detectKind(r'C:\RA\retroarch.exe'), 'retroarch');
    });
    test('matches Dolphin and PCSX2 and PPSSPP', () {
      expect(EmulatorCatalog.detectKind(r'C:\e\Dolphin.exe'), 'dolphin');
      expect(EmulatorCatalog.detectKind(r'C:\e\DolphinQt.exe'), 'dolphin');
      expect(EmulatorCatalog.detectKind(r'C:\e\pcsx2-qt.exe'), 'pcsx2');
      expect(EmulatorCatalog.detectKind(r'C:\e\PPSSPPWindows64.exe'), 'ppsspp');
    });
    test('unknown exe falls back to custom', () {
      expect(EmulatorCatalog.detectKind(r'C:\e\weird.exe'), 'custom');
    });
    test('matches the standalone (non-RetroArch) emulators by exe name', () {
      // Real exe names from an EmuDeck install (the shortcut targets).
      const cases = {
        r'C:\e\azahar\azahar.exe': 'azahar',
        r'C:\e\melonDS\melonDS.exe': 'melonds',
        r'C:\e\cemu\Cemu.exe': 'cemu',
        r'C:\e\Ryujinx\Ryujinx.exe': 'ryujinx',
        r'C:\e\citron\citron.exe': 'citron',
        r'C:\e\eden-windows-msvc\eden.exe': 'eden',
        r'C:\e\RPCS3\rpcs3.exe': 'rpcs3',
        r'C:\e\ShadPS4-qt\shadPS4QtLauncher.exe': 'shadps4',
        r'C:\e\Vita3K\Vita3K.exe': 'vita3k',
        r'C:\e\xemu\xemu.exe': 'xemu',
        r'C:\e\xenia\xenia_canary.exe': 'xenia',
      };
      cases.forEach((path, kind) =>
          expect(EmulatorCatalog.detectKind(path), kind, reason: path));
    });
  });

  group('detectKindFromPackage', () {
    test('maps known emulator packages to their kind', () {
      expect(EmulatorCatalog.detectKindFromPackage('com.retroarch'), 'retroarch');
      expect(EmulatorCatalog.detectKindFromPackage('org.ppsspp.ppsspp'), 'ppsspp');
      expect(
          EmulatorCatalog.detectKindFromPackage('com.github.stenzek.duckstation'),
          'duckstation');
      expect(EmulatorCatalog.detectKindFromPackage('org.dolphinemu.dolphinemu'),
          'dolphin');
    });
    test('unknown package falls back to custom', () {
      expect(EmulatorCatalog.detectKindFromPackage('com.georgeenglezos.notes'), 'custom');
    });
    test('forks are matched by pattern, not by an exact package', () {
      // Package ids the map has never seen. Only com.armsx3 is a real one
      // (confirmed on a device); the rest are stand-ins for the shape a fork
      // takes, since the point is that the matcher doesn't need the real id.
      const forks = {
        'com.armsx3': 'pcsx2',
        'xyz.aethersx2.someotherfork': 'pcsx2',
        'me.magnum.melonds.nightly': 'melonds',
        'org.citra.emu': 'azahar',
        'io.github.azahar_emu.azahar': 'azahar',
        'org.dolphinemu.mmjr': 'dolphin',
        'org.ppsspp.ppssppgold.beta': 'ppsspp',
      };
      for (final entry in forks.entries) {
        expect(EmulatorCatalog.detectKindFromPackage(entry.key), entry.value,
            reason: entry.key);
      }
    });
    test('patterns are specific enough to leave ordinary apps alone', () {
      // Ordinary words show up inside app ids, so the patterns are
      // 'dolphinemu' and 'org.citra' rather than 'dolphin' and 'citra'.
      // com.edenred.eq.myedenred is a real app off a test device: it's why a
      // bare 'eden' pattern (for the Eden emulator) would be unsafe.
      for (final pkg in [
        'com.dolphin.browser',
        'com.citra.bank',
        'com.edenred.eq.myedenred',
        'mobi.infolife.appbackup',
      ]) {
        expect(EmulatorCatalog.detectKindFromPackage(pkg), 'custom',
            reason: pkg);
      }
    });
  });

  group('defaultArgsFor', () {
    test('RetroArch builds -L core path next to the exe', () {
      final args = EmulatorCatalog.defaultArgsFor(
          4, 'retroarch', r'C:\RetroArch-Win64\retroarch.exe');
      // Windows path context: matches how the catalog builds core paths so the
      // expectation holds on any host (including Linux CI).
      final dll =
          p.windows.join(r'C:\RetroArch-Win64', 'cores', 'gambatte_libretro.dll');
      expect(args, '-L "$dll" "{file.path}"');
    });
    test('RetroArch returns null for a console with no core', () {
      expect(EmulatorCatalog.defaultArgsFor(999, 'retroarch', r'C:\r\ra.exe'),
          isNull);
    });
    test('standalone returns the kind args template', () {
      expect(EmulatorCatalog.defaultArgsFor(16, 'dolphin', r'C:\e\Dolphin.exe'),
          '--exec="{file.path}" --batch');
    });
  });

  group('consolesForKind', () {
    test('dolphin covers GameCube (16) and Wii (19)', () {
      final ids = EmulatorCatalog.consolesForKind('dolphin');
      expect(ids.contains(16), isTrue);
      expect(ids.contains(19), isTrue);
      expect(ids.contains(4), isFalse);
    });
    test('retroarch covers Game Boy (4) but not PS2 (21)', () {
      final ids = EmulatorCatalog.consolesForKind('retroarch');
      expect(ids.contains(4), isTrue);
      expect(ids.contains(21), isFalse); // PS2 defaults to pcsx2
    });
    test('standalone kinds default their non-RA display consoles', () {
      // Negative ids are ConsoleMap.displayNames (Switch, Wii U, ...).
      expect(EmulatorCatalog.consolesForKind('ryujinx'), [-1]); // Switch
      expect(EmulatorCatalog.consolesForKind('cemu'), [-2]); // Wii U
      expect(EmulatorCatalog.consolesForKind('xenia'), [-7]); // Xbox 360
      expect(EmulatorCatalog.consolesForKind('azahar'), [62]); // 3DS
    });
  });

  group('standalone launch args', () {
    // These verified args are the whole point of the kind, so they get pinned.
    test('Cemu boots with -g and goes fullscreen with -f', () {
      expect(EmulatorCatalog.defaultArgsFor(-2, 'cemu', r'C:\e\Cemu.exe'),
          '-g "{file.path}"');
      expect(EmulatorCatalog.fullscreenFlag('cemu'), '-f');
    });
    test('xemu boots an ISO with -dvd_path and -full-screen', () {
      expect(EmulatorCatalog.defaultArgsFor(-6, 'xemu', r'C:\e\xemu.exe'),
          '-dvd_path "{file.path}"');
      expect(EmulatorCatalog.fullscreenFlag('xemu'), '-full-screen');
    });
    test('path-only kinds pass just the quoted ROM', () {
      for (final kind in ['rpcs3', 'xenia', 'vita3k', 'azahar', 'ryujinx']) {
        expect(EmulatorCatalog.defaultArgsFor(-3, kind, r'C:\e\emu.exe'),
            '"{file.path}"', reason: kind);
      }
    });
  });

  group('fullscreenFlag', () {
    test('returns the per-kind flag', () {
      expect(EmulatorCatalog.fullscreenFlag('retroarch'), '-f');
      expect(EmulatorCatalog.fullscreenFlag('pcsx2'), '-fullscreen');
      expect(EmulatorCatalog.fullscreenFlag('ppsspp'), '--fullscreen');
    });
    test('is null for kinds without a CLI fullscreen flag', () {
      expect(EmulatorCatalog.fullscreenFlag('dolphin'), isNull);
      expect(EmulatorCatalog.fullscreenFlag('custom'), isNull);
    });

    test('the flag is never baked into the default args', () {
      // It is applied at launch time from the user's preference instead.
      expect(EmulatorCatalog.defaultArgsFor(21, 'pcsx2', r'C:\e\pcsx2-qt.exe'),
          isNot(contains('fullscreen')));
      expect(
          EmulatorCatalog.defaultArgsFor(
              41, 'ppsspp', r'C:\e\PPSSPPWindows64.exe'),
          isNot(contains('fullscreen')));
    });
  });
}
