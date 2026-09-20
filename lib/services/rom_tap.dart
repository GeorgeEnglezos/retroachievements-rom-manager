import 'enum_setting.dart';
import 'pref_keys.dart';

/// What a plain click on a ROM does: open its details dialog, or launch it.
/// Ctrl/shift-click (multi-select) and the right-click menu are unaffected.
enum RomTapAction { detail, play }

/// Live tap preference, shared by both ROM tiles. Settings writes it.
final romTapListenable = EnumSetting(
    PrefKeys.romTapAction, RomTapAction.values, RomTapAction.detail);
