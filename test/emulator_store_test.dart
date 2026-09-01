import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/emulator_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(
      {'flutter.launch_fullscreen': false}));

  test('starts empty', () async {
    expect(await EmulatorStore.emulators(), isEmpty);
    expect(await EmulatorStore.connections(), isEmpty);
    expect(await EmulatorStore.commandFor(4), isNull);
  });

  test('adding RetroArch auto-connects Game Boy with the gambatte core', () async {
    final emu = Emulator(
        id: 'e1',
        name: 'RetroArch',
        exePath: r'C:\RetroArch-Win64\retroarch.exe',
        kindId: 'retroarch');
    await EmulatorStore.addEmulator(emu);

    expect((await EmulatorStore.emulators()).single.id, 'e1');
    expect(
        await EmulatorStore.commandFor(4),
        r'"C:\RetroArch-Win64\retroarch.exe" -L '
        r'"C:\RetroArch-Win64\cores\gambatte_libretro.dll" "{file.path}"');
    expect(await EmulatorStore.commandFor(21), isNull);
  });

  test('adding Dolphin connects only GameCube and Wii, no fullscreen flag',
      () async {
    // Fullscreen on: Dolphin has no CLI flag for it, so the command is unchanged.
    await EmulatorStore.setLaunchFullscreen(true);
    await EmulatorStore.addEmulator(Emulator(
        id: 'd1', name: 'Dolphin', exePath: r'C:\e\Dolphin.exe', kindId: 'dolphin'));
    expect(await EmulatorStore.commandFor(16),
        r'"C:\e\Dolphin.exe" --exec="{file.path}" --batch');
    expect(await EmulatorStore.commandFor(4), isNull);
  });

  test('auto-connect never overwrites an existing connection', () async {
    await EmulatorStore.setConnection(4, 'manual', '-L "x.dll" "{file.path}"');
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\ra\retroarch.exe',
        kindId: 'retroarch'));
    expect((await EmulatorStore.connections())[4]!.emulatorId, 'manual');
  });

  test('removing an emulator drops its connections', () async {
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\ra\retroarch.exe',
        kindId: 'retroarch'));
    expect(await EmulatorStore.commandFor(4), isNotNull);
    await EmulatorStore.removeEmulator('e1');
    expect(await EmulatorStore.emulators(), isEmpty);
    expect(await EmulatorStore.commandFor(4), isNull);
  });

  test('commandFor returns null when the connected emulator is gone', () async {
    await EmulatorStore.setConnection(4, 'ghost', '"{file.path}"');
    expect(await EmulatorStore.commandFor(4), isNull);
  });

  test('setConnection then clearConnection round-trips', () async {
    await EmulatorStore.setConnection(4, 'e1', '"{file.path}"');
    expect((await EmulatorStore.connections())[4]!.emulatorId, 'e1');
    await EmulatorStore.clearConnection(4);
    expect((await EmulatorStore.connections()).containsKey(4), isFalse);
  });

  test('updateEmulatorExe moves default-args connections to the new path',
      () async {
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\old\retroarch.exe',
        kindId: 'retroarch'));
    // Game Boy (4) auto-connected with a default core path under C:\old.
    expect(await EmulatorStore.commandFor(4), contains(r'C:\old\cores'));

    await EmulatorStore.updateEmulatorExe('e1', r'D:\new\retroarch.exe');

    expect((await EmulatorStore.emulators()).single.exePath,
        r'D:\new\retroarch.exe');
    final cmd = await EmulatorStore.commandFor(4);
    expect(cmd, contains(r'D:\new\retroarch.exe'));
    expect(cmd, contains(r'D:\new\cores\gambatte_libretro.dll'));
  });

  test('updateEmulatorExe leaves a custom-edited connection alone', () async {
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\old\retroarch.exe',
        kindId: 'retroarch'));
    await EmulatorStore.setConnection(4, 'e1', '-L "C:\\my\\core.dll" "{file.path}"');
    await EmulatorStore.updateEmulatorExe('e1', r'D:\new\retroarch.exe');
    // exe in the launch command updates, but the hand-edited args are kept.
    expect(await EmulatorStore.commandFor(4),
        r'"D:\new\retroarch.exe" -L "C:\my\core.dll" "{file.path}"');
  });

  test('launchFullscreen defaults to true when unset', () async {
    SharedPreferences.setMockInitialValues({}); // override setUp's false
    expect(await EmulatorStore.launchFullscreen(), isTrue);
  });

  test('setLaunchFullscreen round-trips', () async {
    await EmulatorStore.setLaunchFullscreen(true);
    expect(await EmulatorStore.launchFullscreen(), isTrue);
    await EmulatorStore.setLaunchFullscreen(false);
    expect(await EmulatorStore.launchFullscreen(), isFalse);
  });

  test('commandFor adds the fullscreen flag when enabled', () async {
    await EmulatorStore.setLaunchFullscreen(true);
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\ra\retroarch.exe',
        kindId: 'retroarch'));
    final cmd = await EmulatorStore.commandFor(4);
    expect(cmd, startsWith(r'"C:\ra\retroarch.exe" -f -L'));
  });

  test('commandFor inserts extraArgs before the per-console args', () async {
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\ra\retroarch.exe',
        kindId: 'retroarch'));
    await EmulatorStore.setExtraArgs('e1', '--verbose');
    final cmd = await EmulatorStore.commandFor(4);
    expect(cmd, startsWith(r'"C:\ra\retroarch.exe" --verbose -L'));
  });

  test('Emulator.extraArgs tolerates missing JSON field and round-trips', () async {
    await EmulatorStore.addEmulator(Emulator(
        id: 'e1', name: 'RetroArch', exePath: r'C:\ra\retroarch.exe',
        kindId: 'retroarch', extraArgs: '--foo'));
    expect((await EmulatorStore.emulators()).single.extraArgs, '--foo');
    await EmulatorStore.setExtraArgs('e1', '--bar');
    expect((await EmulatorStore.emulators()).single.extraArgs, '--bar');
  });

  test('takeAndroidSweep is true once, then false forever', () async {
    expect(await EmulatorStore.takeAndroidSweep(), isTrue);
    expect(await EmulatorStore.takeAndroidSweep(), isFalse);
    expect(await EmulatorStore.takeAndroidSweep(), isFalse);
  });
}
