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
  final Color favoriteFill; // favorite card fill
  final Color favoriteInk; // labels/icons on a favorite card

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
    required this.favoriteFill,
    required this.favoriteInk,
    required this.brightness,
    required this.unit,
    required this.radius,
    required this.cardShadow,
    required this.controlShadow,
    required this.borderWidth,
  });

  /// Palette-only const constructor. Every theme shares the same geometry
  /// (8px unit, 16px radius, hairline border, no offset shadows), so an extra
  /// palette declares just its colours and brightness. All the brightness-
  /// keyed getters below then follow from [brightness].
  const UiTokens.palette({
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
    required this.favoriteFill,
    required this.favoriteInk,
    required this.brightness,
  })  : unit = 8,
        radius = 16,
        cardShadow = Offset.zero,
        controlShadow = Offset.zero,
        borderWidth = 1;

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
    favoriteFill: Color(0xFF835F18), // placeholder = accent
    favoriteInk: Color(0xFFF5EFD8), // placeholder = background
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
    favoriteFill: Color(0xFFEF80A9), // placeholder = accent
    favoriteInk: Color(0xFF191627), // placeholder = background
    brightness: Brightness.dark,
    unit: 8,
    radius: 16,
    cardShadow: Offset.zero,
    controlShadow: Offset.zero,
    borderWidth: 1,
  );

  // ── Extra palettes ────────────────────────────────────────────────────────
  // Each clears the same WCAG bar as [light]/[dark]: every ink at 4.5:1 on all
  // three grounds, the border at 3:1 on surface, five distinct accents. See
  // ui_tokens_test.dart, which runs those invariants over every AppTheme.

  /// True black, bright accents: max contrast, OLED-friendly.
  static const UiTokens oled = UiTokens.palette(
    background: Color(0xFF000000),
    surface: Color(0xFF0B0B0B),
    surfaceAlt: Color(0xFF1C1C1C),
    text: Color(0xFFFFFFFF),
    accent: Color(0xFF7DD3FC),
    accentAlt: Color(0xFFC4B5FD),
    accentGames: Color(0xFFFCD34D),
    border: Color(0xFF6E6E6E),
    trough: Color(0xFF000000),
    supported: Color(0xFF6EE7B7),
    warning: Color(0xFFFCA5A5),
    muted: Color(0xFFA6A6A6),
    favoriteFill: Color(0xFF7DD3FC), // placeholder = accent
    favoriteInk: Color(0xFF000000), // placeholder = background
    brightness: Brightness.dark,
  );

  /// Nord: cool polar-night grounds, frost and aurora accents.
  static const UiTokens nord = UiTokens.palette(
    background: Color(0xFF262B35),
    surface: Color(0xFF2F3541),
    surfaceAlt: Color(0xFF3A4150),
    text: Color(0xFFECEFF4),
    accent: Color(0xFF9AD0CF),
    accentAlt: Color(0xFF9BB8DA),
    accentGames: Color(0xFFEBCB8B),
    border: Color(0xFF7E8AA1),
    trough: Color(0xFF262B35),
    supported: Color(0xFFB0C89A),
    warning: Color(0xFFE8A48D),
    muted: Color(0xFFAEB7C7),
    favoriteFill: Color(0xFF9AD0CF), // placeholder = accent
    favoriteInk: Color(0xFF262B35), // placeholder = background
    brightness: Brightness.dark,
  );

  /// GitHub dark: navy-black grounds, GitHub's blue/purple/green accents.
  static const UiTokens github = UiTokens.palette(
    background: Color(0xFF0D1117),
    surface: Color(0xFF161B22),
    surfaceAlt: Color(0xFF232A34),
    text: Color(0xFFE6EDF3),
    accent: Color(0xFF6CB6FF),
    accentAlt: Color(0xFFC297FF),
    accentGames: Color(0xFFE3B341),
    border: Color(0xFF6E7681),
    trough: Color(0xFF0D1117),
    supported: Color(0xFF57D364),
    warning: Color(0xFFF08A8A),
    muted: Color(0xFFA6B0BC),
    favoriteFill: Color(0xFF6CB6FF), // placeholder = accent
    favoriteInk: Color(0xFF0D1117), // placeholder = background
    brightness: Brightness.dark,
  );

  /// Deep violet dark with lavender accents.
  static const UiTokens lavenderDark = UiTokens.palette(
    background: Color(0xFF110F1E),
    surface: Color(0xFF1A1729),
    surfaceAlt: Color(0xFF272338),
    text: Color(0xFFEDE8FF),
    accent: Color(0xFFC4B5FD),
    accentAlt: Color(0xFF93C5FD),
    accentGames: Color(0xFFFCD34D),
    border: Color(0xFF7E72A8),
    trough: Color(0xFF110F1E),
    supported: Color(0xFF6EE7B7),
    warning: Color(0xFFF4A3A3),
    muted: Color(0xFFA99EC9),
    favoriteFill: Color(0xFFC4B5FD), // placeholder = accent
    favoriteInk: Color(0xFF110F1E), // placeholder = background
    brightness: Brightness.dark,
  );

  /// Greyscale dark: black grounds, ink-only accents (hue-blind safe).
  static const UiTokens monochrome = UiTokens.palette(
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    surfaceAlt: Color(0xFF1E1E1E),
    text: Color(0xFFFFFFFF),
    accent: Color(0xFFF0F0F0),
    accentAlt: Color(0xFFC8C8C8),
    accentGames: Color(0xFFD8D8D8),
    border: Color(0xFF6E6E6E),
    trough: Color(0xFF000000),
    supported: Color(0xFFB8B8B8),
    warning: Color(0xFFA6A6A6),
    muted: Color(0xFFAEAEAE),
    favoriteFill: Color(0xFFF0F0F0), // placeholder = accent
    favoriteInk: Color(0xFF000000), // placeholder = background
    brightness: Brightness.dark,
  );

  /// Game Boy DMG: the pea-green LCD, dark-green ink and accents.
  static const UiTokens gameboy = UiTokens.palette(
    background: Color(0xFF9BBC0F),
    surface: Color(0xFFAECB2E),
    surfaceAlt: Color(0xFFC3DA5C),
    text: Color(0xFF0C300C),
    accent: Color(0xFF143C14),
    accentAlt: Color(0xFF0A3A3A),
    accentGames: Color(0xFF4A2F00),
    border: Color(0xFF3A5210),
    trough: Color(0xFF8BAC0F),
    supported: Color(0xFF1F4A00),
    warning: Color(0xFF7A1414),
    muted: Color(0xFF1C4014),
    favoriteFill: Color(0xFF143C14), // placeholder = accent
    favoriteInk: Color(0xFF9BBC0F), // placeholder = background
    brightness: Brightness.light,
  );

  /// Soft lilac light theme.
  static const UiTokens lavenderLight = UiTokens.palette(
    background: Color(0xFFEDEAF7),
    surface: Color(0xFFFAFAFF),
    surfaceAlt: Color(0xFFE6E0F4),
    text: Color(0xFF1C1836),
    accent: Color(0xFF6D28D9),
    accentAlt: Color(0xFF1D4ED8),
    accentGames: Color(0xFF7A5600),
    border: Color(0xFF7C6FA8),
    trough: Color(0xFFDED6F0),
    supported: Color(0xFF1B6B24),
    warning: Color(0xFF9E1B1B),
    muted: Color(0xFF524678),
    favoriteFill: Color(0xFF6D28D9), // placeholder = accent
    favoriteInk: Color(0xFFEDEAF7), // placeholder = background
    brightness: Brightness.light,
  );

  /// Neutral grey light theme with a muted steel-blue accent.
  static const UiTokens slate = UiTokens.palette(
    background: Color(0xFFE8E8E8),
    surface: Color(0xFFF4F4F4),
    surfaceAlt: Color(0xFFE0E0E0),
    text: Color(0xFF1A1A1A),
    accent: Color(0xFF33506F),
    accentAlt: Color(0xFF1D4ED8),
    accentGames: Color(0xFF6E5600),
    border: Color(0xFF808080),
    trough: Color(0xFFDADADA),
    supported: Color(0xFF1B6B24),
    warning: Color(0xFF9E1B1B),
    muted: Color(0xFF515151),
    favoriteFill: Color(0xFF33506F), // placeholder = accent
    favoriteInk: Color(0xFFE8E8E8), // placeholder = background
    brightness: Brightness.light,
  );

  /// Greyscale light: white grounds, ink-only accents (hue-blind safe).
  static const UiTokens monochromeLight = UiTokens.palette(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F5F5),
    surfaceAlt: Color(0xFFE2E2E2),
    text: Color(0xFF000000),
    accent: Color(0xFF1A1A1A),
    accentAlt: Color(0xFF3A3A3A),
    accentGames: Color(0xFF505050),
    border: Color(0xFF757575),
    trough: Color(0xFFE2E2E2),
    supported: Color(0xFF2E2E2E),
    warning: Color(0xFF444444),
    muted: Color(0xFF505050),
    favoriteFill: Color(0xFF1A1A1A), // placeholder = accent
    favoriteInk: Color(0xFFFFFFFF), // placeholder = background
    brightness: Brightness.light,
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

  /// Backdrop for console tiles and home shortcut cards. Full-color console
  /// logos need a light backdrop, so both palettes render these on a light
  /// surface (with dark ink): warm beige in light, white in dark.
  Color get cardSurface => brightness == Brightness.light
      ? const Color(0xFFEDEBE3)
      : const Color(0xFFFFFFFF);

  /// Background of the selected nav tab. Light fills with the theme [accent]
  /// (matching the segmented toggles) so the pill wears the palette's own
  /// colour; dark uses the raised surface, as the reference sidebar does.
  Color get navSelectedBg =>
      brightness == Brightness.light ? accent : surfaceAlt;

  /// Label/icon color on the selected nav tab: the ground colour on light's
  /// accent fill (as the toggles do), normal ink on dark's raised surface.
  Color get navSelectedFg =>
      brightness == Brightness.light ? background : text;

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
    Color? favoriteFill,
    Color? favoriteInk,
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
        favoriteFill: favoriteFill ?? this.favoriteFill,
        favoriteInk: favoriteInk ?? this.favoriteInk,
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
      favoriteFill: Color.lerp(favoriteFill, other.favoriteFill, t)!,
      favoriteInk: Color.lerp(favoriteInk, other.favoriteInk, t)!,
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
