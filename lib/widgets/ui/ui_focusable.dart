import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// The one-shot motion a surface plays the moment it gains focus/hover.
enum FocusFlourish {
  /// No motion on highlight. Standard interactive controls (buttons, chips, tabs).
  none,

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
  /// cards, `ui.roundMd` for buttons, etc.); the ring is grown by [ringGap] so
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

  /// Whether to render the highlight border ring on focus/hover.
  final bool showRing;

  /// Distance between content edge and accent ring. Defaults to 4.
  final double ringGap;

  /// Whether to render the blurred drop shadow behind a lifted ([focusScale]
  /// > 1.0) surface on focus/hover. Defaults to true; a dense grid of small
  /// tiles (the ROM grid) sets this false — the blur reads as a muddy halo at
  /// that size — while keeping the zoom and ring.
  final bool showShadow;

  const UiFocusable({
    super.key,
    required this.child,
    required this.borderRadius,
    this.onPressed,
    this.focusScale = 1.0,
    this.ringColor,
    this.flourish = FocusFlourish.tilt,
    this.showRing = true,
    this.ringGap = _defaultRingGap,
    this.showShadow = true,
  });

  @override
  State<UiFocusable> createState() => _UiFocusableState();
}

/// Default gap between the content edge and the accent ring.
const double _defaultRingGap = 4;

class _UiFocusableState extends State<UiFocusable>
    with SingleTickerProviderStateMixin {
  bool _focused = false;
  bool _hovered = false;

  AnimationController? _flourishCtl;
  Animation<double>? _angle;
  Animation<double>? _hop;

  @override
  void initState() {
    super.initState();
    _initFlourish();
  }

  void _initFlourish() {
    if (widget.flourish == FocusFlourish.none) return;
    final ctl = AnimationController(
      vsync: this,
      duration: widget.flourish == FocusFlourish.jump
          ? const Duration(milliseconds: 260)
          : const Duration(milliseconds: 520),
    );
    _flourishCtl = ctl;
    if (widget.flourish == FocusFlourish.tilt) {
      // Spring wiggle: playful initial tilt left, lively rebound right, then
      // soft settle upright (Switch card / cartridge feel).
      _angle = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 0.0,
            end: -0.065,
          ).chain(CurveTween(curve: Curves.easeOutQuad)),
          weight: 28,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: -0.065,
            end: 0.025,
          ).chain(CurveTween(curve: Curves.easeInOutQuad)),
          weight: 36,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 0.025,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 36,
        ),
      ]).animate(ctl);
    } else if (widget.flourish == FocusFlourish.jump) {
      _hop = TweenSequence<double>([
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
      ]).animate(ctl);
    }
  }

  bool get _lit => _focused || _hovered;

  void _setLit({bool? focus, bool? hover}) {
    final was = _lit;
    setState(() {
      if (focus != null) _focused = focus;
      if (hover != null) _hovered = hover;
    });
    if (!was && _lit) _flourishCtl?.forward(from: 0); // rising edge → flourish
  }

  @override
  void dispose() {
    _flourishCtl?.dispose();
    super.dispose();
  }

  // The surface's radius grown by [widget.ringGap] so the outset ring stays concentric.
  BorderRadius get _ringRadius {
    final r = widget.borderRadius;
    final g = Radius.circular(widget.ringGap);
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
    final hasLift = widget.focusScale > 1.0;
    final shadowColor = ui.brightness == Brightness.light
        ? Colors.black.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.55);

    final content = Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        if (hasLift && widget.showShadow)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _lit ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        widget.child,
        if (_lit && widget.showRing)
          Positioned(
            left: -widget.ringGap,
            top: -widget.ringGap,
            right: -widget.ringGap,
            bottom: -widget.ringGap,
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
    );

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
        child: _flourishCtl == null
            ? content
            : AnimatedBuilder(
                animation: _flourishCtl!,
                builder: (_, child) {
                  final t = widget.flourish == FocusFlourish.tilt
                      ? Matrix4.rotationZ(_angle!.value)
                      : Matrix4.translationValues(0, _hop!.value, 0);
                  return Transform(
                    transform: t,
                    alignment: Alignment.center,
                    child: child,
                  );
                },
                child: content,
              ),
      ),
    );
  }
}
