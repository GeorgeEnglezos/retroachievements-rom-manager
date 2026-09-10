import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import '../../theme/ui_theme.dart';
import 'ui_card.dart';

/// A [UiCard] that always renders on a light backdrop with dark ink, in both
/// themes; used by the console tiles (full-color logos) and the home shortcut
/// cards (All games, playlists) so they read the same everywhere. The surface
/// color comes from [UiTokens.cardSurface] on the active theme.
class ConsoleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  const ConsoleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    // Read the surface + app accent off the real theme before the light-theme
    // override, so the focus ring wears the app's accent, not light's amber.
    final color = context.ui.cardSurface;
    final ring = context.ui.accent;
    return Theme(
      data: uiTheme(UiTokens.light),
      child: UiCard(
        onTap: onTap,
        color: color,
        padding: padding,
        ringColor: ring,
        child: child,
      ),
    );
  }
}
