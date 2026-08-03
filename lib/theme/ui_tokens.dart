import 'package:flutter/material.dart';

/// Fixed accent hues used across widgets: purple favorite and red danger read
/// the same in both palettes, so they live outside the palette tokens.
const Color kFavoriteColor = Color(0xFF8B5CF6);
const Color kDangerColor = Color(0xFFE53935);

/// Design tokens, attached to [ThemeData] as a [ThemeExtension] and read via
/// `Theme.of(context).extension<UiTokens>()!` or `context.ui`. Ships two
/// palettes: [light] (Game Boy) and [dark] (RetroAchievements dark).
@immutable
class UiTokens extends ThemeExtension<UiTokens> {
  // Palette (role-based)
  final Color background; // app background / scaffold
  final Color surface; // card / panel surface
  final Color text; // primary text + icons
  final Color accent; // primary accent: buttons, links, selection, active, error
  final Color accentGames; // game-specific highlight (e.g. ACH badge)
  final Color border; // outline color
  final Color trough; // progress trough / inset fill
  final Color supported; // supported / has-achievements status
  final Color warning; // error status
  final Color muted; // secondary text

  // Geometry
  final Brightness brightness;
  final double unit;
  final Offset cardShadow;
  final Offset controlShadow;
  final double borderWidth;

  const UiTokens({
    required this.background,
    required this.surface,
    required this.text,
    required this.accent,
    required this.accentGames,
    required this.border,
    required this.trough,
    required this.supported,
    required this.warning,
    required this.muted,
    required this.brightness,
    required this.unit,
    required this.cardShadow,
    required this.controlShadow,
    required this.borderWidth,
  });

  // Generic warm light theme: yellowish retro tint, no pure-white surfaces
  // (easier on the eyes), amber accent in place of the old GB red/green.
  static const UiTokens light = UiTokens(
    background: Color(0xFFF5EFD8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF1A1A1A),
    accent: Color(0xFFA6791E),
    accentGames: Color(0xFF7A6A1E), // olive: warm game highlight / ACH badge
    border: Color(0xFF3A3428),
    trough: Color(0xFFE6DCC0),
    supported: Color(0xFF5B7A2E),
    warning: Color(0xFFC98A1E),
    muted: Color(0xFF7A7364),
    brightness: Brightness.light,
    unit: 8,
    cardShadow: Offset.zero,
    controlShadow: Offset.zero,
    borderWidth: 2,
  );

  static const UiTokens dark = UiTokens(
    background: Color(0xFF1A1A1A),
    surface: Color(0xFF2A2A2A),
    text: Color(0xFF2C97FA),
    accent: Color(0xFF2C97FA),
    accentGames: Color(0xFFCC9900),
    border: Color(0xFF3A3A3A),
    trough: Color(0xFF1A1A1A),
    supported: Color(0xFF2E7D32),
    warning: Color(0xFFE0A800),
    muted: Color(0xFF9AA0A6),
    brightness: Brightness.dark,
    unit: 8,
    cardShadow: Offset.zero,
    controlShadow: Offset.zero,
    borderWidth: 1,
  );

  /// Backwards-compatible alias used by the `context.ui` fallback and tests.
  static const UiTokens standard = light;

  /// Favorite-row wash. Light uses solid black (labels flip to white); dark
  /// keeps the low-alpha purple accent.
  Color get favoriteHighlight => brightness == Brightness.light
      ? const Color(0xFF000000)
      : kFavoriteColor.withValues(alpha: 0.14);

  /// Backdrop for console tiles and home shortcut cards. Full-color console
  /// logos need a light backdrop, so both palettes render these on a light
  /// surface (with dark ink): warm beige in light, white in dark.
  Color get cardSurface => brightness == Brightness.light
      ? const Color(0xFFEDEBE3)
      : const Color(0xFFFFFFFF);

  /// Label/icon color for favorite rows. Null keeps the default text color;
  /// light returns white because [favoriteHighlight] is solid black there.
  Color? get favoriteText =>
      brightness == Brightness.light ? const Color(0xFFFFFFFF) : null;

  /// Background of the selected nav tab. Light uses black, dark the accent.
  Color get navSelectedBg =>
      brightness == Brightness.light ? const Color(0xFF000000) : accent;

  /// Label/icon color on the selected nav tab: white on both selected
  /// backgrounds (dark's accent equals [text], which would vanish on it).
  Color get navSelectedFg => const Color(0xFFFFFFFF);

  /// Hard offset shadow (no blur). Returns no shadow when the offset is zero.
  List<BoxShadow> shadow([Offset? offset]) {
    final o = offset ?? cardShadow;
    if (o == Offset.zero) return const [];
    return [BoxShadow(color: border, offset: o, blurRadius: 0)];
  }

  TextStyle get display => TextStyle(
        fontFamily: 'HankenGrotesk',
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: text,
        letterSpacing: 0.5,
      );

  TextStyle get labelCaps => TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: text,
        letterSpacing: 1.2,
      );

  TextStyle get body => TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        fontSize: 13,
        color: text,
      );

  TextStyle get mono => TextStyle(
        fontFamily: 'JetBrainsMono',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: text,
      );

  @override
  UiTokens copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? accent,
    Color? accentGames,
    Color? border,
    Color? trough,
    Color? supported,
    Color? warning,
    Color? muted,
    Brightness? brightness,
    double? unit,
    Offset? cardShadow,
    Offset? controlShadow,
    double? borderWidth,
  }) =>
      UiTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        accent: accent ?? this.accent,
        accentGames: accentGames ?? this.accentGames,
        border: border ?? this.border,
        trough: trough ?? this.trough,
        supported: supported ?? this.supported,
        warning: warning ?? this.warning,
        muted: muted ?? this.muted,
        brightness: brightness ?? this.brightness,
        unit: unit ?? this.unit,
        cardShadow: cardShadow ?? this.cardShadow,
        controlShadow: controlShadow ?? this.controlShadow,
        borderWidth: borderWidth ?? this.borderWidth,
      );

  @override
  UiTokens lerp(ThemeExtension<UiTokens>? other, double t) {
    if (other is! UiTokens) return this;
    return UiTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentGames: Color.lerp(accentGames, other.accentGames, t)!,
      border: Color.lerp(border, other.border, t)!,
      trough: Color.lerp(trough, other.trough, t)!,
      supported: Color.lerp(supported, other.supported, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
      unit: _lerpDouble(unit, other.unit, t),
      cardShadow: Offset.lerp(cardShadow, other.cardShadow, t)!,
      controlShadow: Offset.lerp(controlShadow, other.controlShadow, t)!,
      borderWidth: _lerpDouble(borderWidth, other.borderWidth, t),
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension UiContext on BuildContext {
  UiTokens get ui =>
      Theme.of(this).extension<UiTokens>() ?? UiTokens.standard;
}
