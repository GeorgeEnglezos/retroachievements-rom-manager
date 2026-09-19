import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_theme.dart';
import 'ui_card.dart';

// UiCard is a plain Container, so a Theme override alone never reaches an
// unstyled Text: DefaultTextStyle comes from the nearest ancestor Material,
// which sits outside these cards. Labels kept the app palette's ink (light
// grey on the white plate in dark themes) while anything reading Theme.of got
// light's black. Pair the two so a card's whole subtree is light.
final ThemeData lightCardTheme = uiTheme(UiTokens.light);

/// Wraps [child] in the light card palette, ink included.
Widget lightCardInk({required Widget child}) => Theme(
  data: lightCardTheme,
  child: DefaultTextStyle(
    style: lightCardTheme.textTheme.bodyMedium!,
    child: child,
  ),
);

/// A [UiCard] that always renders on a light backdrop with dark ink, in both
/// themes; used by the console tiles (full-color logos) and the home shortcut
/// cards (All games, playlists) so they read the same everywhere. The surface
/// color comes from [UiTokens.cardSurface] on the active theme.
class ConsoleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final FocusFlourish flourish;

  /// Focus/hover zoom factor. Use > 1.0 for square grid tiles to get the
  /// "pop" effect (zoom + elevated shadow). Leave at 1.0 for list rows.
  final double focusScale;

  /// Whether to render the accent ring on focus/hover. Set to false for
  /// grid tiles using the pure zoom + shadow style.
  final bool showRing;

  const ConsoleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
    this.flourish = FocusFlourish.tilt,
    this.focusScale = 1.0,
    this.showRing = true,
  });

  @override
  Widget build(BuildContext context) {
    // Read the surface + app accent off the real theme before the light-theme
    // override, so the focus ring wears the app's accent, not light's amber.
    final color = context.ui.cardSurface;
    final ring = context.ui.accent;
    return lightCardInk(
      child: UiCard(
        onTap: onTap,
        color: color,
        borderColor: borderColor,
        padding: padding,
        ringColor: ring,
        flourish: flourish,
        focusScale: focusScale,
        showRing: showRing,
        child: child,
      ),
    );
  }
}
