import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pref_keys.dart';

/// What a plain click on a ROM does: open its details dialog, or launch it.
/// Ctrl/shift-click (multi-select) and the right-click menu are unaffected.
enum RomTapAction { detail, play }

/// Live tap preference, shared by both ROM tiles. Settings writes it.
final ValueNotifier<RomTapAction> romTapListenable =
    ValueNotifier(RomTapAction.detail);

/// Reads the saved action into [romTapListenable]. Call once at startup.
Future<void> initRomTap() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(PrefKeys.romTapAction);
  romTapListenable.value =
      RomTapAction.values.where((a) => a.name == stored).firstOrNull ??
          RomTapAction.detail;
}

/// Persists the chosen action and publishes it to listeners.
Future<void> saveRomTapAction(RomTapAction action) async {
  romTapListenable.value = action;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefKeys.romTapAction, action.name);
}
