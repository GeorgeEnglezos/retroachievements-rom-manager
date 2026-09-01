import 'package:flutter/material.dart';
import 'ui_tokens.dart';

/// Builds the app-wide Material3 theme seeded to the given [UiTokens] palette
/// and attaches it as a theme extension.
ThemeData uiTheme(UiTokens t) {
  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: t.brightness,
  ).copyWith(
    // Material chrome (AppBar, dialogs) uses the app background, matching the
    // original DMG mapping; custom widgets paint their own t.surface.
    surface: t.background,
    primary: t.accent,
    onPrimary: t.background,
    onSurface: t.text,
    error: t.warning,
  );

  final control = RoundedRectangleBorder(borderRadius: t.roundMd);
  final panel = RoundedRectangleBorder(borderRadius: t.roundLg);
  OutlineInputBorder inputBorder(Color c) => OutlineInputBorder(
        borderRadius: t.roundMd,
        borderSide: BorderSide(color: c, width: t.borderWidth),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.background,
    fontFamily: 'Inter',
    extensions: [t],
    textTheme: const TextTheme().apply(
      bodyColor: t.text,
      displayColor: t.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: inputBorder(t.border),
      enabledBorder: inputBorder(t.border),
      focusedBorder: inputBorder(t.accent),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.accent,
        foregroundColor: t.background,
        shape: control,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: control),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.border, width: t.borderWidth),
        shape: control,
      ),
    ),
    // Sub-tabs read as an underlined strip on the page, not as a filled band:
    // the accent marks the active label and a hairline carries the rest.
    tabBarTheme: TabBarThemeData(
      labelColor: t.accent,
      unselectedLabelColor: t.muted,
      indicatorColor: t.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: t.border,
      dividerHeight: t.borderWidth,
      labelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w400),
      overlayColor: WidgetStatePropertyAll(t.accent.withValues(alpha: 0.06)),
    ),
    cardTheme: CardThemeData(shape: panel),
    dialogTheme: DialogThemeData(shape: panel),
  );
}
