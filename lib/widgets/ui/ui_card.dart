import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'ui_focusable.dart';
export 'ui_focusable.dart' show FocusFlourish, UiFocusZoom, uiFocusZoom;

/// Rounded surface with a hairline border. Both palettes currently use a zero
/// shadow offset, so the press feedback (translate + drop shadow) only shows if
/// a palette sets a non-zero [UiTokens.cardShadow] again.
class UiCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// Focus/hover lift. Defaults to the shared [uiFocusZoom]; square game-tile
  /// cards pass a bigger value to opt into the full pop.
  final double focusScale;

  /// One-shot focus motion (see [UiFocusable.flourish]). List rows pass
  /// [FocusFlourish.jump]; grid tiles keep the default tilt.
  final FocusFlourish flourish;

  /// Whether to render the blurred drop shadow on a lifted card (see
  /// [UiFocusable.showShadow]).
  final bool showShadow;

  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.color,
    this.borderColor,
    this.focusScale = uiFocusZoom,
    this.flourish = FocusFlourish.tilt,
    this.showShadow = true,
  });

  @override
  State<UiCard> createState() => _CardState();
}

class _CardState extends State<UiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final pressed = _pressed && widget.onTap != null;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      transform: Matrix4.translationValues(
        pressed ? ui.cardShadow.dx : 0,
        pressed ? ui.cardShadow.dy : 0,
        0,
      ),
      padding: widget.padding,
      // Most callers pass padding: zero and a full-bleed child (box art, the
      // storage size bar, a group stripe). Container does not clip to its own
      // borderRadius by default, so without this those paint square corners
      // over the rounded edge.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.color ?? ui.surface,
        borderRadius: ui.roundLg,
        boxShadow: pressed ? const [] : ui.shadow(),
      ),
      // Border drawn on top of the (clipped) child: antialiased corner clipping
      // shaves a border painted in the same decoration, eating 1-2px of the
      // hairline at each rounded corner.
      foregroundDecoration: BoxDecoration(
        borderRadius: ui.roundLg,
        border: Border.all(
          color: widget.borderColor ?? ui.border,
          width: ui.borderWidth,
        ),
      ),
      // The card's own background is a DecoratedBox, so a ListTile-family child
      // would paint its background and ink splashes on whatever Material sits
      // further up (the Scaffold), behind this card. Flutter asserts on that.
      // A transparent Material here paints nothing and gives them one to use.
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
    if (widget.onTap == null) return body;
    // Pointer taps + press animation on the GestureDetector; focus/hover
    // zoom and gamepad/keyboard activation on the UiFocusable shell.
    return UiFocusable(
      onPressed: widget.onTap,
      borderRadius: ui.roundLg,
      focusScale: widget.focusScale,
      flourish: widget.flourish,
      showShadow: widget.showShadow,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}
