import '../theme/ui_tokens.dart';
import 'enum_setting.dart';

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
  gameboy('Game Boy', UiTokens.gameboy),
  lavenderLight('Lavender Light', UiTokens.lavenderLight),
  slate('Slate', UiTokens.slate),
  monochromeLight('Monochrome', UiTokens.monochromeLight);

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
