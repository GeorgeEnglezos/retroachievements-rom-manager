import 'package:flutter/foundation.dart';

import 'app_mode.dart';
import 'app_theme.dart';
import 'display_name.dart';
import 'library_folder.dart';
import 'play_view.dart';
import 'rom_tap.dart';
import 'scan_settings.dart';
import 'ui_scale.dart';

/// Settings written straight to prefs with no listenable of their own
/// (username, API key). Bumped by the writer; nothing listens to it directly.
final ValueNotifier<int> otherSettingsListenable = ValueNotifier(0);

/// Call right after writing a setting that has no listenable of its own.
void publishSettingsChange() => otherSettingsListenable.value++;

/// Every settings signal in one [Listenable]. Screens sit in the shell's
/// IndexedStack and are never rebuilt from scratch, so whatever they cached
/// from a setting goes stale the moment Settings writes it. Listening here
/// instead of hand-picking notifiers is the point: each screen used to pick a
/// subset and silently miss the rest, which is why some settings only applied
/// after a restart.
final Listenable settingsChanged = Listenable.merge([
  appModeListenable,
  appThemeListenable,
  combineSystemsListenable,
  libraryFolderListenable,
  nameModeListenable,
  otherSettingsListenable,
  playViewListenable,
  romTapListenable,
  scanFiltersListenable,
  uiScaleListenable,
]);
