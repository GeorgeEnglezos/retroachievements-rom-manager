import '../theme/ui_tokens.dart';
import 'enum_setting.dart';
import '../strings.dart';

/// Which visual theme the app uses. Each case carries its display [label] and
/// its [tokens] palette; [AppTheme.values] is the ordered list the picker
/// renders, and [name] is the key persisted to prefs.
enum AppTheme {
  dark(ThemeStrings.retroAchievements, UiTokens.dark),
  light(ThemeStrings.light, UiTokens.light),
  oled(ThemeStrings.oled, UiTokens.oled),
  nord(ThemeStrings.nord, UiTokens.nord),
  github(ThemeStrings.github, UiTokens.github),
  lavenderDark(ThemeStrings.lavenderDark, UiTokens.lavenderDark),
  gameboy(ThemeStrings.gameboy, UiTokens.gameboy),
  lavenderLight(ThemeStrings.lavenderLight, UiTokens.lavenderLight),
  slate(ThemeStrings.slate, UiTokens.slate),
  monochromeLight(ThemeStrings.monochrome, UiTokens.monochromeLight);

  const AppTheme(this.label, this.tokens);
  final String label;
  final UiTokens tokens;
}

const _appThemeKey = 'app_theme';

/// Live theme selection, shared across screens. Settings writes it; [main]
/// rebuilds [MaterialApp] from it so a change applies immediately. Defaults to
/// [AppTheme.dark], the RetroAchievements look.
final appThemeListenable =
    EnumSetting(_appThemeKey, AppTheme.values, AppTheme.dark);
