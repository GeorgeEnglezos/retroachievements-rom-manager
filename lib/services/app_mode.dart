import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pref_keys.dart';

/// How much of the app is on show.
///
/// [cleaning] is the full library-maintenance UI. [gaming] is the
/// browse-and-play surface other frontends call kiosk mode: the maintenance
/// tabs, scans, multi-select and every delete/exclude affordance are hidden,
/// so handing someone the app can't cost them ROMs. A controller drives either
/// mode; connecting one no longer switches modes on its own.
enum AppMode { cleaning, gaming }


/// Live mode selection, shared across screens. Settings writes it; [AppShell]
/// rebuilds from it, which re-runs every mounted screen's build.
final ValueNotifier<AppMode> appModeListenable = ValueNotifier(AppMode.cleaning);

/// True while a play-only surface is active (gaming or big picture). Widgets
/// read this straight, without a listener: everything below the shell rebuilds
/// when the mode flips. It gates the destructive affordances, so every play
/// surface must count as gaming.
bool get gamingMode => appModeListenable.value != AppMode.cleaning;

/// Loads the saved mode, defaulting to [AppMode.cleaning] (managing a library
/// is what the app is for; play mode is the thing you switch into).
Future<AppMode> loadAppMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(PrefKeys.appMode);
  return AppMode.values.where((m) => m.name == stored).firstOrNull ??
      AppMode.cleaning;
}

/// Reads the saved mode into [appModeListenable]. Call once at startup.
Future<void> initAppMode() async {
  appModeListenable.value = await loadAppMode();
}

/// Persists the chosen mode and publishes it to listeners.
Future<void> saveAppMode(AppMode mode) async {
  appModeListenable.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefKeys.appMode, mode.name);
}
