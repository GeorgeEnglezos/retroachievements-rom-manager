import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// The one-shot motion a surface plays the moment it gains focus/hover.
enum FocusFlourish {
  /// Tilt left a few degrees, then settle upright. Square game tiles.
  tilt,

  /// A small, quick vertical hop. Wide list rows, where a tilt reads as too big.
  jump,
}

/// Shared focus/hover shell for every tappable surface in the design system.
///
/// The design-system primitives are built on plain [GestureDetector]s, which
/// aren't focusable — so gamepad/keyboard traversal had nothing to land on and
/// mouse hover gave no feedback. Wrap a tappable surface in this and it becomes
/// focusable (the [GamepadNavigator] drives Flutter's focus system, so this is
/// what a d-pad now moves between), activates on the controller's A / Enter /
/// Space via [ActivateIntent], and shows a modern selection state when focused
/// OR hovered:
///
///  * a crisp accent ring sitting a few px *outside* the surface (at its own
///    [borderRadius], grown to match), so it frames the content instead of
///    painting over the edge of the art/text,
///  * a smooth zoom to [focusScale], and
///  * a one-shot [flourish] (tilt for tiles, light jump for rows) so a d-pad
///    move reads as a little lively snap rather than a static box.
class UiFocusable extends StatefulWidget {
  final Widget child;

  /// Fired by the controller's A button / Enter / Space (the [ActivateIntent]).
  /// Pointer taps still go through the child's own gesture handler; this only
  /// wires up keyboard/gamepad activation. Null makes the surface non-focusable
  /// (a display-only card shouldn't grab d-pad focus).
  final VoidCallback? onPressed;

  /// Radius the accent ring follows — pass the surface's own (`ui.roundLg` for
  /// cards, `ui.roundMd` for buttons, etc.); the ring is grown by [_ringGap] so
  /// it hugs a slightly larger rounded rect than the content.
  final BorderRadius borderRadius;

  /// How much the surface grows when highlighted. Defaults to 1.0 (ring only)
  /// so wide rows never overflow their neighbours; square game tiles pass ~1.08
  /// to opt into the zoom.
  // ponytail: an interior grid tile scaling/tilting up paints over its
  // neighbours (a deliberate "pop"); an edge tile clips at the viewport. Fine.
  final double focusScale;

  /// Ring colour. Defaults to the theme accent; [ConsoleCard] overrides it
  /// because it forces a light sub-theme whose accent wouldn't match the app.
  final Color? ringColor;

  /// Which one-shot motion to play on focus gain.
  final FocusFlourish flourish;

  const UiFocusable({
    super.key,
    required this.child,
    required this.borderRadius,
    this.onPressed,
    this.focusScale = 1.0,
    this.ringColor,
    this.flourish = FocusFlourish.tilt,
  });

  @override
  State<UiFocusable> createState() => _UiFocusableState();
}

/// Gap between the content edge and the accent ring, so the ring frames the
/// tile rather than overlapping its art/text.
const double _ringGap = 4;

class _UiFocusableState extends State<UiFocusable>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  bool _hovered = false;

  // The one-shot flourish, driven 0→1 once each time the surface gains
  // highlight. Both curves start and end at 0, so at rest (value 0 before the
  // first play, value 1 after) the transform is identity.
  late final AnimationController _flourishCtl = AnimationController(
    vsync: this,
    duration: widget.flourish == FocusFlourish.jump
        ? const Duration(milliseconds: 260)
        : const Duration(milliseconds: 480),
  );

  // Tilt: ~4° left fast, then ease back upright.
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -0.07,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -0.07,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 70,
    ),
  ]).animate(_flourishCtl);

  // Jump: a small, quick hop up and back down.
  late final Animation<double> _hop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -5.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -5.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 60,
    ),
  ]).animate(_flourishCtl);

  bool get _lit => _focused || _hovered;

  void _setLit({bool? focus, bool? hover}) {
    final was = _lit;
    setState(() {
      if (focus != null) _focused = focus;
      if (hover != null) _hovered = hover;
    });
    if (!was && _lit) _flourishCtl.forward(from: 0); // rising edge → flourish
  }

  @override
  void dispose() {
    _flourishCtl.dispose();
    super.dispose();
  }

  // The surface's radius grown by [_ringGap] so the outset ring stays concentric.
  BorderRadius get _ringRadius {
    final r = widget.borderRadius;
    const g = Radius.circular(_ringGap);
    return BorderRadius.only(
      topLeft: r.topLeft + g,
      topRight: r.topRight + g,
      bottomLeft: r.bottomLeft + g,
      bottomRight: r.bottomRight + g,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final enabled = widget.onPressed != null;
    final ring = widget.ringColor ?? ui.accent;
    final scale = _lit ? widget.focusScale : 1.0;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => _setLit(focus: v),
      onShowHoverHighlight: (v) => _setLit(hover: v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed?.call();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _flourishCtl,
          builder: (_, child) {
            final t = widget.flourish == FocusFlourish.tilt
                ? Matrix4.rotationZ(_angle.value)
                : Matrix4.translationValues(0, _hop.value, 0);
            return Transform(
              transform: t,
              alignment: Alignment.center,
              child: child,
            );
          },
          // Ring drawn as a sibling positioned _ringGap outside the child, so it
          // frames the content without overlapping it and without affecting
          // layout (Clip.none lets the outset paint past the child's bounds).
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (_lit)
                Positioned(
                  left: -_ringGap,
                  top: -_ringGap,
                  right: -_ringGap,
                  bottom: -_ringGap,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: _ringRadius,
                        border: Border.all(color: ring, width: 2.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
