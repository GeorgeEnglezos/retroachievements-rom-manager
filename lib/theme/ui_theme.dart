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
    error: t.accent,
  );

  const zero = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  OutlineInputBorder inputBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.zero,
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
        shape: zero,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: zero),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.text,
        side: BorderSide(color: t.border, width: t.borderWidth),
        shape: zero,
      ),
    ),
    cardTheme: const CardThemeData(shape: zero),
    dialogTheme: const DialogThemeData(shape: zero),
  );
}
