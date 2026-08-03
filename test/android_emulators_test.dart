import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/android_emulators.dart';

void main() {
  group('buildLaunchSpec', () {
    test('melonDS standalone uses LAUNCH_ROM action + uri extra', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'me.magnum.melonds', 'melonds', 18, '/roms/game.nds');
      expect(spec['action'], 'me.magnum.melonds.LAUNCH_ROM');
      expect(spec['componentClass'],
          'me.magnum.melonds.ui.emulator.EmulatorActivity');
      expect((spec['extras'] as Map)['uri'], '{file.uri}');
    });

    test('melonDualDS fork gets the same melonDS intent', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'me.magnum.melondualds', 'melonds', 18, '/roms/game.nds');
      expect(spec['action'], 'me.magnum.melonds.LAUNCH_ROM');
      expect(spec['componentPkg'], 'me.magnum.melondualds');
      expect(spec['componentClass'],
          'me.magnum.melonds.ui.emulator.EmulatorActivity');
    });

    test('AetherSX2 boots via EmulationActivity + bootPath', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'xyz.aethersx2.android', 'pcsx2', 21, '/roms/game.iso');
      expect(spec['componentClass'], 'xyz.aethersx2.android.EmulationActivity');
      expect(spec['action'], 'android.intent.action.MAIN');
      expect((spec['extras'] as Map)['bootPath'], '{file.uri}');
    });

    test('NetherSX2 turnip fork keeps the AetherSX2 activity', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'xyz.aethersx2.tturnip', 'pcsx2', 21, '/roms/game.iso');
      expect(spec['componentClass'], 'xyz.aethersx2.android.EmulationActivity');
      expect((spec['extras'] as Map)['bootPath'], '{file.uri}');
    });

    test('ArmSX2 boots via ACTION_VIEW + URI on an explicit component', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'com.armsx2', 'pcsx2', 21, '/roms/game.iso');
      // Explicit component required: a package-only VIEW intent throws
      // ActivityNotFoundException on ArmSX2.
      expect(spec['componentPkg'], 'com.armsx2');
      expect(spec['componentClass'], 'com.armsx2.Main');
      expect(spec['action'], 'android.intent.action.VIEW');
      expect(spec['data'], '{file.uri}');
      // Not AetherSX2's component/bootPath.
      expect(spec.containsKey('extras'), isFalse);
    });

    test('Dolphin auto-boots via the intent data content URI', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'org.dolphinemu.dolphinemu', 'dolphin', 16, '/roms/game.rvz');
      expect(spec['componentClass'],
          'org.dolphinemu.dolphinemu.ui.main.MainActivity');
      expect(spec['action'], 'android.intent.action.MAIN');
      // ROM handed to Dolphin as intent.data (grantable content URI), which its
      // StartupHandler reads before the AutoStartFile extra.
      expect(spec['data'], '{file.uri}');
      expect(spec.containsKey('extras'), isFalse);
    });

    test('RetroArch known console gets ROM/LIBRETRO/CONFIGFILE extras', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'com.retroarch.aarch64', 'retroarch', 3, '/roms/game.sfc');
      final extras = spec['extras'] as Map;
      expect(extras['ROM'], '{file.path}');
      expect(extras['LIBRETRO'],
          contains('snes9x_libretro_android.so'));
      expect(extras.containsKey('CONFIGFILE'), isTrue);
    });

    test('unknown app falls back to generic open-file intent', () {
      final spec = AndroidEmulators.buildLaunchSpec(
          'com.some.unknown.emu', 'custom', 12, '/roms/game.chd');
      expect(spec['setPackage'], 'com.some.unknown.emu');
      expect(spec['mimeType'], 'application/octet-stream');
    });
  });
}
