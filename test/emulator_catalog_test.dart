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
