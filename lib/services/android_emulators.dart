import 'package:flutter/services.dart';

import 'emulator_catalog.dart';

/// A ROM launch parked because the app was opened by tapping a home-screen
/// shortcut. Drained once by [AndroidEmulators.takePendingShortcut].
class PendingShortcut {
  final String package;
  final String kindId;
  final int consoleId;
  final String romPath;

  const PendingShortcut({
    required this.package,
    required this.kindId,
    required this.consoleId,
    required this.romPath,
  });
}

/// An installed Android app that can be picked as an emulator.
class InstalledApp {
  final String package;
  final String label;
  final bool known; // true for emulators we recognise (sorted first)

  const InstalledApp(
      {required this.package, required this.label, required this.known});
}

/// Android-only bridge (method channel): emulators are apps launched via
/// intents, not exes. Callers guard with `Platform.isAndroid`.
class AndroidEmulators {
  AndroidEmulators._();

  static const _channel = MethodChannel('rarm/emulators');

  /// Launchable apps on the device, known emulators first. Empty on failure.
  static Future<List<InstalledApp>> installedApps() async {
    List<Map<dynamic, dynamic>>? raw;
    try {
      raw = await _channel
          .invokeListMethod<Map<dynamic, dynamic>>('installedApps');
    } on PlatformException catch (_) {
      return [];
    } on MissingPluginException catch (_) {
      return [];
    }
    if (raw == null) return [];
    return raw.map((m) {
      final package = m['package'] as String;
      return InstalledApp(
        package: package,
        label: m['label'] as String,
        // Derived from the catalog rather than sent by the native side, so
        // adding an emulator there is the only edit a new package needs.
        known: EmulatorCatalog.detectKindFromPackage(package) !=
            EmulatorCatalog.customKindId,
      );
    }).toList()
      ..sort((a, b) => a.known == b.known
          ? a.label.toLowerCase().compareTo(b.label.toLowerCase())
          : (a.known ? -1 : 1));
  }

  /// Opens [romPath] in [package] via the right intent for [kindId]/[consoleId].
  /// Returns null on success, or a short error string (the native exception).
  static Future<String?> launchRom({
    required String package,
    required String kindId,
    required int consoleId,
    required String romPath,
  }) async =>
      _channel.invokeMethod<String>(
          'launchRom', buildLaunchSpec(package, kindId, consoleId, romPath));

  /// Pins a home-screen shortcut re-launching [romPath] in [package]; null on
  /// success. [iconPath] box art falls back to the app icon.
  static Future<String?> createShortcut({
    required String package,
    required String label,
    required String kindId,
    required int consoleId,
    required String romPath,
    String? iconPath,
  }) =>
      _channel.invokeMethod<String>('createShortcut', {
        'package': package,
        'label': label,
        'kindId': kindId,
        'consoleId': consoleId,
        'romPath': romPath,
        'iconPath': iconPath,
      });

  /// Drains a shortcut launch parked when the app was opened from a home-screen
  /// shortcut. Returns null when nothing is pending. Consumed once.
  static Future<PendingShortcut?> takePendingShortcut() async {
    final m = await _channel
        .invokeMapMethod<String, dynamic>('takePendingShortcut');
    if (m == null) return null;
    return PendingShortcut(
      package: m['package'] as String,
      kindId: m['kindId'] as String? ?? '',
      consoleId: m['consoleId'] as int? ?? 0,
      romPath: m['romPath'] as String,
    );
  }

  /// Launch spec -> intent. Each emulator needs explicit activity + extras
  /// (generic open-file throws in RetroArch); {file.path}/{file.uri}
  /// substituted natively. Unknown apps fall back to ACTION_VIEW.
  ///
  /// Package-family checks come before the [kindId] switch because several
  /// PS2/DS emulators share a kind but need different intents (verified against
  /// ES-DE's Android es_systems.xml). Detecting by package also fixes emulators
  /// added before they were catalogued (their stored kindId is 'custom').
  static Map<String, dynamic> buildLaunchSpec(
      String pkg, String kindId, int consoleId, String romPath) {
    // melonDS family (standalone DS): official, .dev and melonDualDS forks all
    // share one activity/action/extra, only the package differs.
    if (pkg.startsWith('me.magnum.melonds') || pkg == 'me.magnum.melondualds') {
      return {
        'romPath': romPath,
        'componentPkg': pkg,
        'componentClass': 'me.magnum.melonds.ui.emulator.EmulatorActivity',
        'action': 'me.magnum.melonds.LAUNCH_ROM',
        'extras': {'uri': '{file.uri}'},
        'clearTask': true,
      };
    }
    // AetherSX2 / NetherSX2: the turnip/classic NetherSX2 forks keep AetherSX2's
    // package prefix and activity class, so match on the shared 'aethersx2' name.
    if (pkg.contains('aethersx2')) {
      return {
        'romPath': romPath,
        'componentPkg': pkg,
        'componentClass': 'xyz.aethersx2.android.EmulationActivity',
        'action': 'android.intent.action.MAIN',
        'extras': {'bootPath': '{file.uri}'},
        'clearTask': true,
      };
    }
    // ArmSX2 / ArmSX3 (com.armsx2, com.armsx3, com.nanodata.armsx2): a separate
    // PS2 emulator that boots via ACTION_VIEW on the ROM URI. It needs an
    // EXPLICIT component (a package-only VIEW intent throws
    // ActivityNotFoundException), and the activity class differs per build.
    // ArmSX3 ships the same com.armsx2.* classes, so it takes the default.
    if (pkg.contains('armsx')) {
      const armsx2Activity = {
        'com.armsx2': 'com.armsx2.Main',
        'com.nanodata.armsx2': 'kr.co.iefriends.pcsx2.MainActivity',
      };
      return {
        'romPath': romPath,
        'componentPkg': pkg,
        'componentClass': armsx2Activity[pkg] ?? 'com.armsx2.Main',
        'action': 'android.intent.action.VIEW',
        'data': '{file.uri}',
        'clearTask': true,
      };
    }
    switch (kindId) {
      case 'retroarch':
        final core = EmulatorCatalog.retroArchCore[consoleId];
        if (core != null) {
          return {
            'romPath': romPath,
            'componentPkg': pkg,
            'componentClass':
                'com.retroarch.browser.retroactivity.RetroActivityFuture',
            'clearTask': true,
            'extras': {
              'ROM': '{file.path}',
              'LIBRETRO': '/data/data/$pkg/cores/${core}_libretro_android.so',
              'CONFIGFILE':
                  '/storage/emulated/0/Android/data/$pkg/files/retroarch.cfg',
            },
          };
        }
      case 'ppsspp':
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          'componentClass': 'org.ppsspp.ppsspp.PpssppActivity',
          'action': 'android.intent.action.VIEW',
          'category': 'android.intent.category.DEFAULT',
          'data': '{file.uri}',
          'mimeType': 'application/octet-stream',
          'clearTask': true,
          'noHistory': true,
        };
      case 'duckstation':
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          'componentClass': 'com.github.stenzek.duckstation.EmulationActivity',
          'extras': {'bootPath': '{file.uri}'},
          'extrasBool': {'resumeState': false},
          'clearTask': true,
        };
      case 'dolphin':
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          'componentClass': 'org.dolphinemu.dolphinemu.ui.main.MainActivity',
          'action': 'android.intent.action.MAIN',
          // Pass the ROM as the intent DATA content URI. Dolphin's
          // StartupHandler reads intent.data before the AutoStartFile extra, and
          // FLAG_GRANT_READ_URI_PERMISSION only covers intent.data, so Dolphin
          // can read it without its own all-files access. A raw AutoStartFile
          // path silently fails when Dolphin lacks storage permission, dropping
          // the user at the game list instead of booting.
          'data': '{file.uri}',
          'clearTask': true,
        };
      case 'pcsx2': // AetherSX2 / NetherSX2
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          'componentClass': 'xyz.aethersx2.android.EmulationActivity',
          'action': 'android.intent.action.MAIN',
          'extras': {'bootPath': '{file.uri}'},
          'clearTask': true,
        };
      case 'citra': // 3DS: Lime3DS, Azahar, Citra MMJ
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          // Verified against Lime3DS: EmulationActivity's VIEW filter takes a
          // content URI typed application/octet-stream. Every Citra fork keeps
          // the class, only the package differs.
          'componentClass': 'org.citra.citra_emu.activities.EmulationActivity',
          'action': 'android.intent.action.VIEW',
          'data': '{file.uri}',
          'mimeType': 'application/octet-stream',
          'clearTask': true,
        };
      case 'flycast':
        return {
          'romPath': romPath,
          'componentPkg': pkg,
          // Flycast's VIEW filter declares scheme "file" only, and we hand out
          // content URIs, so name the activity explicitly (an explicit
          // component skips filter matching) instead of using setPackage.
          'componentClass': 'com.flycast.emulator.MainActivity',
          'action': 'android.intent.action.VIEW',
          'data': '{file.uri}',
          'clearTask': true,
        };
    }
    // Unknown / uncatalogued app: best-effort generic open-file intent.
    return {
      'romPath': romPath,
      'setPackage': pkg,
      'data': '{file.uri}',
      'mimeType': 'application/octet-stream',
    };
  }
}
