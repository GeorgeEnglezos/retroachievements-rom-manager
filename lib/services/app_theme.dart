import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_tokens.dart';

/// Which visual theme the app uses. Each case carries its display [label] and
/// its [tokens] palette; [AppTheme.values] is the ordered list the picker
/// renders, and [name] is the key persisted to prefs.
enum AppTheme {
  dark('RetroAchievements', UiTokens.dark),
  light('Light', UiTokens.light),
  oled('OLED', UiTokens.oled),
  nord('Nord', UiTokens.nord),
  github('GitHub', UiTokens.github),
  lavenderDark('Lavender Dark', UiTokens.lavenderDark),
  monochrome('Monochrome', UiTokens.monochrome),
  gameboy('Game Boy', UiTokens.gameboy),
  lavenderLight('Lavender Light', UiTokens.lavenderLight),
  slate('Slate', UiTokens.slate),
  monochromeLight('Monochrome Light', UiTokens.monochromeLight);

  const AppTheme(this.label, this.tokens);
  final String label;
  final UiTokens tokens;
}

const _appThemeKey = 'app_theme';

/// Live theme selection, shared across screens. Settings writes it; [main]
/// rebuilds [MaterialApp] from it so a change applies immediately.
final ValueNotifier<AppTheme> appThemeListenable = ValueNotifier(AppTheme.dark);

/// Loads the saved theme, defaulting to [AppTheme.dark] (the RetroAchievements look).
Future<AppTheme> loadAppTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_appThemeKey);
  return AppTheme.values.where((t) => t.name == stored).firstOrNull ??
      AppTheme.dark;
}

/// Reads the saved theme into [appThemeListenable]. Call once at startup.
Future<void> initAppTheme() async {
  appThemeListenable.value = await loadAppTheme();
}

/// Persists the chosen theme and publishes it to listeners.
Future<void> saveAppTheme(AppTheme theme) async {
  appThemeListenable.value = theme;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_appThemeKey, theme.name);
}
