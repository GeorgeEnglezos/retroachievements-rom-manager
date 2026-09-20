import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'console_map.dart';
import 'enum_setting.dart';
import 'pref_keys.dart';

/// How folder cards, the folder view title, and combined-system labels show a
/// system: by its full RetroAchievements name or by the original folder name.
enum NameMode { systemName, folderName }

const _nameModeKey = 'name_display_mode';

/// The live name mode, shared across screens. Screens listen to this so a change
/// made on the Settings tab applies immediately even though the IndexedStack
/// nav keeps them all alive (they are never popped/reloaded).
final nameModeListenable =
    EnumSetting(_nameModeKey, NameMode.values, NameMode.systemName);

/// Label for a folder (or combined group): folder name(s) or RA console name
/// per [mode], falling back to folder names when the console is unknown.
String displayNameFor({
  required NameMode mode,
  int? consoleId,
  required List<String> folderPaths,
}) {
  final folderName = folderPaths.map((path) => p.basename(path)).join(' / ');
  if (mode == NameMode.folderName) return folderName;
  return ConsoleMap.nameFor(consoleId) ?? folderName;
}

/// Whether the home grid merges folders that map to the same console into one
/// card. Shared the same way as [nameModeListenable].
final ValueNotifier<bool> combineSystemsListenable = ValueNotifier(false);

/// Reads the saved combine flag into [combineSystemsListenable]. Call once at
/// startup so the first build uses the saved value.
Future<void> initCombineSystems() async {
  final prefs = await SharedPreferences.getInstance();
  combineSystemsListenable.value =
      prefs.getBool(PrefKeys.homeCombineSystems) ?? false;
}

/// Persists the combine flag and publishes it to listeners.
Future<void> saveCombineSystems(bool on) async {
  combineSystemsListenable.value = on;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(PrefKeys.homeCombineSystems, on);
}
