import 'package:path/path.dart' as p;

/// A known emulator type with launch defaults sourced from Playnite's emulator
/// database (source/Playnite/Emulation/Emulators/*/emulator.yaml).
class EmulatorKind {
  final String id;
  final String name;
  final RegExp exePattern; // matched against the exe file name
  final String? standaloneArgs; // null for RetroArch (core-based, per system)
  final String? fullscreenFlag; // CLI flag for fullscreen, or null if none

  const EmulatorKind(this.id, this.name, this.exePattern, this.standaloneArgs,
      this.fullscreenFlag);
}

/// Pure catalog: which emulator/core each console defaults to, and how to build
/// its launch arguments. No persistence; see [EmulatorStore].
class EmulatorCatalog {
  EmulatorCatalog._();

  static const customKindId = 'custom';

  /// Known emulator kinds. Order matters: first matching [exePattern] wins.
  static final List<EmulatorKind> kinds = [
    EmulatorKind('retroarch', 'RetroArch',
        RegExp(r'retroarch', caseSensitive: false), null, '-f'),
    // Anchored (unlike the others) because "dolphin" is a common word; covers
    // both Dolphin.exe and the Qt build DolphinQt.exe. No CLI fullscreen flag.
    EmulatorKind('dolphin', 'Dolphin',
        RegExp(r'^dolphin(qt)?\.exe$', caseSensitive: false),
        '--exec="{file.path}" --batch', null),
    EmulatorKind('pcsx2', 'PCSX2',
        RegExp(r'pcsx2', caseSensitive: false),
        '-slowboot -- "{file.path}"', '-fullscreen'),
    EmulatorKind('duckstation', 'DuckStation',
        RegExp(r'duckstation', caseSensitive: false),
        '-batch "{file.path}"', '-fullscreen'),
    EmulatorKind('ppsspp', 'PPSSPP',
        RegExp(r'ppsspp', caseSensitive: false),
        '"{file.path}" --pause-menu-exit', '--fullscreen'),
    // Standalone emulators for systems RetroArch doesn't cover. Args from
    // Playnite's emulator database (or the emulator's own docs for the newer
    // forks). Exe patterns anchored, since these names are short and generic.
    // Beta: not all launch end to end yet — the connection args are editable.
    EmulatorKind('azahar', 'Azahar', // 3DS (Citra fork)
        RegExp(r'^azahar\.exe$', caseSensitive: false), '"{file.path}"', null),
    EmulatorKind('melonds', 'melonDS', // DS / DSi
        RegExp(r'^melonds\.exe$', caseSensitive: false), '"{file.path}"', '-f'),
    EmulatorKind('cemu', 'Cemu', // Wii U
        RegExp(r'^cemu.*\.exe$', caseSensitive: false),
        '-g "{file.path}"', '-f'),
    EmulatorKind('ryujinx', 'Ryujinx', // Switch
        RegExp(r'^ryujinx(\.ava)?\.exe$', caseSensitive: false),
        '"{file.path}"', '--fullscreen'),
    // yuzu forks: args read off their own shortcut builder (`-g "<path>"`,
    // `-f` for fullscreen), not the bare positional path.
    EmulatorKind('citron', 'Citron', // Switch (yuzu fork)
        RegExp(r'^citron\.exe$', caseSensitive: false), '-g "{file.path}"', '-f'),
    EmulatorKind('eden', 'Eden', // Switch (yuzu fork)
        RegExp(r'^eden\.exe$', caseSensitive: false), '-g "{file.path}"', '-f'),
    EmulatorKind('rpcs3', 'RPCS3', // PS3
        RegExp(r'^rpcs3.*\.exe$', caseSensitive: false), '"{file.path}"', null),
    EmulatorKind('shadps4', 'shadPS4', // PS4
        RegExp(r'^shadps4.*\.exe$', caseSensitive: false),
        '"{file.path}"', null),
    EmulatorKind('vita3k', 'Vita3K', // PS Vita
        RegExp(r'^vita3k.*\.exe$', caseSensitive: false), '"{file.path}"', null),
    EmulatorKind('xemu', 'xemu', // Original Xbox
        RegExp(r'^xemu\.exe$', caseSensitive: false),
        '-dvd_path "{file.path}"', '-full-screen'),
    EmulatorKind('xenia', 'Xenia', // Xbox 360
        RegExp(r'^xenia.*\.exe$', caseSensitive: false), '"{file.path}"', null),
  ];

  /// RA console id -> default emulator kind id.
  static const Map<int, String> defaultKind = {
    1: 'retroarch', 2: 'retroarch', 3: 'retroarch', 4: 'retroarch',
    5: 'retroarch', 6: 'retroarch', 7: 'retroarch', 8: 'retroarch',
    9: 'retroarch', 10: 'retroarch', 11: 'retroarch', 12: 'retroarch',
    13: 'retroarch', 14: 'retroarch', 15: 'retroarch', 16: 'dolphin',
    17: 'retroarch', 18: 'retroarch', 21: 'pcsx2', 24: 'retroarch',
    25: 'retroarch', 27: 'retroarch', 28: 'retroarch', 39: 'retroarch',
    40: 'retroarch', 41: 'ppsspp', 43: 'retroarch', 19: 'dolphin',
    51: 'retroarch', 53: 'retroarch', 76: 'retroarch',
    // Standalone-only systems. 62 (3DS) has no libretro core; the negative ids
    // are the non-RA display consoles (see ConsoleMap.displayNames). DS (18)
    // stays on RetroArch's melonDS core; standalone melonDS defaults DSi (78).
    62: 'azahar', 78: 'melonds',
    -2: 'cemu', -1: 'ryujinx', -3: 'rpcs3', -4: 'shadps4',
    -5: 'vita3k', -6: 'xemu', -7: 'xenia',
  };

  /// RA console id -> RetroArch core base name (gets `_libretro.dll`).
  static const Map<int, String> retroArchCore = {
    1: 'genesis_plus_gx', 2: 'mupen64plus_next', 3: 'snes9x', 4: 'gambatte',
    5: 'mgba', 6: 'gambatte', 7: 'fceumm', 8: 'mednafen_pce',
    9: 'genesis_plus_gx', 10: 'picodrive', 11: 'genesis_plus_gx',
    12: 'swanstation', 13: 'handy', 14: 'mednafen_ngp', 15: 'genesis_plus_gx',
    17: 'virtualjaguar', 18: 'melonds', 24: 'pokemini', 25: 'stella',
    27: 'fbneo', 28: 'mednafen_vb', 39: 'mednafen_saturn', 40: 'flycast',
    43: 'opera', 51: 'prosystem', 53: 'mednafen_wswan', 76: 'mednafen_pce',
  };

  /// The CLI flag that makes [kindId] launch fullscreen, or null when the kind
  /// has none (Dolphin, custom).
  static String? fullscreenFlag(String kindId) => kindById(kindId)?.fullscreenFlag;

  static EmulatorKind? kindById(String id) {
    for (final k in kinds) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Android package name -> catalog kind id. Used so a picked emulator app maps
  /// to the same kind as its desktop build (for naming/consistency); launching
  /// on Android is generic (intent), so this doesn't affect args.
  static const Map<String, String> androidPackageKind = {
    'com.retroarch': 'retroarch',
    'com.retroarch.aarch64': 'retroarch',
    'org.ppsspp.ppsspp': 'ppsspp',
    'org.ppsspp.ppssppgold': 'ppsspp',
    'com.github.stenzek.duckstation': 'duckstation',
    'org.dolphinemu.dolphinemu': 'dolphin',
    // PS2: AetherSX2 + the NetherSX2 turnip/classic forks + ArmSX2/ArmSX3.
    'xyz.aethersx2.android': 'pcsx2',
    'xyz.aethersx2.tturnip': 'pcsx2',
    'xyz.aethersx2.cturnip': 'pcsx2',
    'com.armsx2': 'pcsx2',
    'com.armsx3': 'pcsx2',
    'com.nanodata.armsx2': 'pcsx2',
    // Dreamcast: standalone Flycast. Console 40 still defaults to RetroArch
    // (which runs the same core), so this one is connected by hand.
    'com.flycast.emulator': 'flycast',
    // Nintendo DS: melonDS official, .dev and the melonDualDS dual-screen fork.
    'me.magnum.melonds': 'melonds',
    'me.magnum.melonds.dev': 'melonds',
    'me.magnum.melondualds': 'melonds',
    // 3DS: Lime3DS, and by pattern the rest of the Citra family (Citra MMJ,
    // Azahar). They all ship org.citra.citra_emu.* classes.
    'io.github.lime3ds.android': 'citra',
  };

  /// Substring fallbacks, checked after [androidPackageKind]. Emulators fork
  /// faster than a package list can be maintained (ArmSX3, melonDS .dev,
  /// Lime3DS, Azahar, the MMJ builds), and every fork keeps the original name
  /// in its id. Keep each pattern specific enough not to catch ordinary apps:
  /// `dolphinemu`, not `dolphin`, or Dolphin Browser matches; `org.citra`, not
  /// `citra`, which is a common word in other app ids.
  static const _packagePatterns = {
    'retroarch': 'retroarch',
    'ppsspp': 'ppsspp',
    'duckstation': 'duckstation',
    'dolphinemu': 'dolphin',
    'aethersx2': 'pcsx2',
    'armsx': 'pcsx2',
    'pcsx2': 'pcsx2',
    'melonds': 'melonds',
    'melondual': 'melonds',
    'org.citra': 'citra',
    'citra_emu': 'citra',
    'lime3ds': 'citra',
    'azahar': 'citra',
    'flycast': 'flycast',
  };

  /// Emulator kind id for an Android [package]; [customKindId] if unknown.
  static String detectKindFromPackage(String package) {
    final exact = androidPackageKind[package];
    if (exact != null) return exact;
    final lower = package.toLowerCase();
    for (final entry in _packagePatterns.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return customKindId;
  }

  /// Best-effort emulator kind id from an exe path; [customKindId] if none match.
  static String detectKind(String exePath) {
    // Windows-only app: parse with the windows context so backslash paths are
    // split correctly even when this runs on a non-Windows host (e.g. CI).
    final name = p.windows.basename(exePath);
    for (final k in kinds) {
      if (k.exePattern.hasMatch(name)) return k.id;
    }
    return customKindId;
  }

  /// Default launch args (program excluded, with {file.path}) for [consoleId]
  /// under an emulator of [kindId] at [exePath], or null when there's no
  /// sensible default (e.g. RetroArch with no known core for the console).
  static String? defaultArgsFor(int consoleId, String kindId, String exePath) {
    if (kindId == 'retroarch') {
      final core = retroArchCore[consoleId];
      if (core == null) return null;
      // Windows-only app: cores are `<exeDir>\cores\<core>_libretro.dll`.
      // Use the windows context so parsing works off-Windows (CI) too.
      final dll =
          p.windows.join(p.windows.dirname(exePath), 'cores', '${core}_libretro.dll');
      return '-L "$dll" "{file.path}"';
    }
    return kindById(kindId)?.standaloneArgs;
  }

  /// Kinds that can run a console besides its [defaultKind] entry. Switch is
  /// the only system with several maintained emulators today; add a console
  /// here when a second one is worth offering.
  static const Map<int, List<String>> _alsoRunKinds = {
    -1: ['citron', 'eden'],
  };

  /// Every kind that can run [consoleId], the default first. Drives the
  /// "Play with…" picker; [defaultKind] still decides auto-connect.
  static List<String> kindsForConsole(int consoleId) => [
        if (defaultKind[consoleId] != null) defaultKind[consoleId]!,
        ...?_alsoRunKinds[consoleId],
      ];

  /// Console ids whose default kind is [kindId] (used for auto-connect).
  static List<int> consolesForKind(String kindId) => defaultKind.entries
      .where((e) => e.value == kindId)
      .map((e) => e.key)
      .toList();
}
