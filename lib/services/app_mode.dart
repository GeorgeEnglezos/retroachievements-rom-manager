import 'enum_setting.dart';
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
/// rebuilds from it, which re-runs every mounted screen's build. Defaults to
/// [AppMode.cleaning]: managing a library is what the app is for, play mode is
/// the thing you switch into.
final appModeListenable =
    EnumSetting(PrefKeys.appMode, AppMode.values, AppMode.cleaning);

/// True while a play-only surface is active (gaming or big picture). Widgets
/// read this straight, without a listener: everything below the shell rebuilds
/// when the mode flips. It gates the destructive affordances, so every play
/// surface must count as gaming.
bool get gamingMode => appModeListenable.value != AppMode.cleaning;
