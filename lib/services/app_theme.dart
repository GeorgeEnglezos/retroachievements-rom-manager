import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_tokens.dart';

/// Which visual theme the app uses.
enum AppTheme { light, dark }

const _appThemeKey = 'app_theme';

/// Live theme selection, shared across screens. Settings writes it; [main]
/// rebuilds [MaterialApp] from it so a change applies immediately.
final ValueNotifier<AppTheme> appThemeListenable = ValueNotifier(AppTheme.dark);

/// The token palette for a theme.
UiTokens paletteFor(AppTheme theme) =>
    theme == AppTheme.dark ? UiTokens.dark : UiTokens.light;

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
