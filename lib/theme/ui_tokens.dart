import 'package:flutter/material.dart';

/// Fixed accent hues used across widgets: purple favorite and red danger read
/// the same in both palettes, so they live outside the palette tokens.
const Color kFavoriteColor = Color(0xFF8B5CF6);
const Color kDangerColor = Color(0xFFE53935);

/// Cover-art scrim and the ink that sits on it. Box art is full-colour in
/// either palette, so text over it needs a fixed dark veil and light ink
/// rather than palette tokens that would invert with the theme. Fixed for the
/// same reason [kFavoriteColor] is. Used by the dashboard hero and the cover
/// tiles; reach for these instead of a new black-and-white pair.
const Color kScrim = Color(0xFF1A1622);
const Color kOnScrim = Color(0xFFF8F5EE);
const Color kOnScrimMuted = Color(0xFFCFC7D8);

/// Accent for anything highlighted on the scrim: labels, readouts, progress
/// fills. The scrim is dark in both themes, so light's olive [UiTokens.accent]
/// hues sit at ~3:1 on it; butter clears 12:1 either way.
const Color kOnScrimAccent = Color(0xFFFCDC7E);

/// Design tokens, attached to [ThemeData] as a [ThemeExtension] and read via
/// `Theme.of(context).extension<UiTokens>()!` or `context.ui`. Ships two
/// palettes: [light] (warm retro) and [dark] (candy cartridge: deep indigo
/// surfaces, warm cream ink, five pastel accents).
///
/// Never hardcode a color or a corner radius in a widget: take it from here.
@immutable
class UiTokens extends ThemeExtension<UiTokens> {
  // Palette (role-based)
  final Color background; // app background / scaffold
  final Color surface; // card / panel surface
  final Color surfaceAlt; // raised surface: hover, selected row, active tab
  final Color text; // primary text + icons
  final Color accent; // primary accent: buttons, links, selection, active, error
  final Color accentAlt; // secondary accent, 3rd hue of the accent set
  final Color accentGames; // game-specific highlight (e.g. ACH badge)
  final Color border; // outline color
  final Color trough; // progress trough / inset fill
  final Color supported; // supported / has-achievements status
  final Color warning; // error status
  final Color muted; // secondary text

  // Geometry
  final Brightness brightness;
  final double unit;
  final double radius; // base corner radius; see roundSm/roundMd/roundLg
  final Offset cardShadow;
  final Offset controlShadow;
  final double borderWidth;

  const UiTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.accent,
    required this.accentAlt,
    required this.accentGames,
    required this.border,
    required this.trough,
    required this.supported,
    required this.warning,
    required this.muted,
    required this.brightness,
    required this.unit,
    required this.radius,
    required this.cardShadow,
    required this.controlShadow,
    required this.borderWidth,
  });

  // Warm light theme: yellowish retro tint, no pure-white surfaces (easier on
  // the eyes), amber accent. Same geometry as [dark]: rounded, hairline border.
  static const UiTokens light = UiTokens(
    background: Color(0xFFF5EFD8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEDE5CB),
    text: Color(0xFF1A1A1A),
    accent: Color(0xFF835F18),
    accentAlt: Color(0xFF3C6A88), // slate blue: 3rd hue of the accent set
    accentGames: Color(0xFF74651D), // olive: warm game highlight / ACH badge
    border: Color(0xFF3A3428),
    trough: Color(0xFFE6DCC0),
    supported: Color(0xFF526E2A),
    warning: Color(0xFF885D14),
    muted: Color(0xFF6B6457),
    brightness: Brightness.light,
    unit: 8,
    radius: 16,
    cardShadow: Offset.zero,
    controlShadow: Offset.zero,
    borderWidth: 1,
  );

  // "Candy cartridge": deep indigo surfaces, warm cream ink, five pastel
  // accents (candy / mint / sky / butter / coral). The border is a 38% cream
  // hairline rather than a drawn outline: with both shadow offsets at zero it
  // is the only thing separating a card from its ground, so it has to clear
  // the 3:1 WCAG asks of a component boundary.
  static const UiTokens dark = UiTokens(
    background: Color(0xFF191627),
    surface: Color(0xFF241F37),
    surfaceAlt: Color(0xFF312B4A),
    text: Color(0xFFF8F1E3),
    accent: Color(0xFFEF80A9), // candy
    accentAlt: Color(0xFF86D2F3), // sky
    accentGames: Color(0xFFFCDC7E), // butter
    border: Color(0x60F8F1E3), // cream at 38%
    trough: Color(0xFF191627),
    supported: Color(0xFF7DE8D3), // mint
    warning: Color(0xFFF59F85), // coral
    muted: Color(0xA7DDCEB1), // warm cream at 65%
    brightness: Brightness.dark,
    unit: 8,
    radius: 16,
    cardShadow: Offset.zero,
    controlShadow: Offset.zero,
    borderWidth: 1,
  );

  /// Backwards-compatible alias used by the `context.ui` fallback and tests.
  static const UiTokens standard = light;

  /// Corner radii, derived from [radius] the way the reference design system
  /// derives its scale. Small: badges, thumbnails, inline fills. Medium:
  /// buttons, controls, avatars. Large: cards, panels, dialogs.
  BorderRadius get roundSm => BorderRadius.circular(radius - 6);
  BorderRadius get roundMd => BorderRadius.circular(radius + 6);
  BorderRadius get roundLg => BorderRadius.circular(radius + 12);

  /// Fully rounded: progress bars, chips, status pills.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// The five-hue accent set, in order. Use it wherever a palette of distinct
  /// but equal colors is needed (folder group headers, per-item highlights).
  List<Color> get accents =>
      [accent, supported, accentAlt, accentGames, warning];

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

  /// Background of the selected nav tab. Light uses black; dark uses the
  /// raised surface, as the reference sidebar does.
  Color get navSelectedBg =>
      brightness == Brightness.light ? const Color(0xFF000000) : surfaceAlt;

  /// Label/icon color on the selected nav tab: white on light's black fill,
  /// normal cream ink on dark's raised surface.
  Color get navSelectedFg =>
      brightness == Brightness.light ? const Color(0xFFFFFFFF) : text;

  /// Hard offset shadow (no blur). Returns no shadow when the offset is zero.
  List<BoxShadow> shadow([Offset? offset]) {
    final o = offset ?? cardShadow;
    if (o == Offset.zero) return const [];
    return [BoxShadow(color: border, offset: o, blurRadius: 0)];
  }

  TextStyle get display => TextStyle(
        fontFamily: 'HankenGrotesk',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: text,
        height: 1.05,
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
    Color? surfaceAlt,
    Color? text,
    Color? accent,
    Color? accentAlt,
    Color? accentGames,
    Color? border,
    Color? trough,
    Color? supported,
    Color? warning,
    Color? muted,
    Brightness? brightness,
    double? unit,
    double? radius,
    Offset? cardShadow,
    Offset? controlShadow,
    double? borderWidth,
  }) =>
      UiTokens(
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        text: text ?? this.text,
        accent: accent ?? this.accent,
        accentAlt: accentAlt ?? this.accentAlt,
        accentGames: accentGames ?? this.accentGames,
        border: border ?? this.border,
        trough: trough ?? this.trough,
        supported: supported ?? this.supported,
        warning: warning ?? this.warning,
        muted: muted ?? this.muted,
        brightness: brightness ?? this.brightness,
        unit: unit ?? this.unit,
        radius: radius ?? this.radius,
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
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      text: Color.lerp(text, other.text, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      accentGames: Color.lerp(accentGames, other.accentGames, t)!,
      border: Color.lerp(border, other.border, t)!,
      trough: Color.lerp(trough, other.trough, t)!,
      supported: Color.lerp(supported, other.supported, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
      unit: _lerpDouble(unit, other.unit, t),
      radius: _lerpDouble(radius, other.radius, t),
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
