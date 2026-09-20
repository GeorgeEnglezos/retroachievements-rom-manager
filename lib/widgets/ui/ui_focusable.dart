import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// The slight zoom every focusable surface plays on highlight. Game tiles pass
/// a bigger scale of their own; everything else shares this.
const double uiFocusZoom = 1.02;

/// Slight highlight zoom for controls that already own a focus node: the raw
/// Material buttons, text fields, list tiles and nav rows that never went
/// through [UiFocusable]. Fires on focus (keyboard arrows, gamepad) and on
/// mouse hover, the same pair [UiFocusable] reacts to. Unlike [UiFocusable] it
/// adds no second tab stop (its [Focus] can't take focus itself, it only hears
/// a descendant take it) and no ring or activation, which the wrapped Material
/// widget already handles.
class UiFocusZoom extends StatefulWidget {
  final Widget child;
  final double scale;

  const UiFocusZoom({super.key, required this.child, this.scale = uiFocusZoom});

  @override
  State<UiFocusZoom> createState() => _UiFocusZoomState();
}

class _UiFocusZoomState extends State<UiFocusZoom> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (v) => setState(() => _focused = v),
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _focused || _hovered ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    ),
  );
}

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
///  * a smooth zoom to [focusScale] (no border or ring: the highlight is
///    motion only), and
///  * a one-shot [flourish] (tilt for tiles, light jump for rows) so a d-pad
///    move reads as a little lively snap rather than a static box.
class UiFocusable extends StatefulWidget {
  final Widget child;

  /// Fired by the controller's A button / Enter / Space (the [ActivateIntent]).
  /// Pointer taps still go through the child's own gesture handler; this only
  /// wires up keyboard/gamepad activation. Null makes the surface non-focusable
  /// (a display-only card shouldn't grab d-pad focus).
  final VoidCallback? onPressed;

  /// Radius the lift shadow follows — pass the surface's own (`ui.roundLg`
  /// for cards, `ui.roundMd` for buttons, etc.).
  final BorderRadius borderRadius;

  /// How much the surface grows when highlighted. Defaults to the shared
  /// [uiFocusZoom] slight lift; square game tiles pass a much bigger value to
  /// opt into the full pop.
  // ponytail: an interior grid tile scaling/tilting up paints over its
  // neighbours (a deliberate "pop"); an edge tile clips at the viewport. Fine.
  final double focusScale;

  /// Which one-shot motion to play on focus gain.
  final FocusFlourish flourish;

  /// Whether to render the blurred drop shadow behind a lifted ([focusScale]
  /// > 1.0) surface on focus/hover. Defaults to true; a dense grid of small
  /// tiles (the ROM grid) sets this false — the blur reads as a muddy halo at
  /// that size — while keeping the zoom.
  final bool showShadow;

  const UiFocusable({
    super.key,
    required this.child,
    required this.borderRadius,
    this.onPressed,
    this.focusScale = uiFocusZoom,
    this.flourish = FocusFlourish.tilt,
    this.showShadow = true,
  });

  @override
  State<UiFocusable> createState() => _UiFocusableState();
}

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

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final enabled = widget.onPressed != null;
    final scale = _lit ? widget.focusScale : 1.0;
    // Only a real pop (the game tiles) earns the drop shadow; under the
    // default slight zoom it just smears a halo behind every button and row.
    final hasLift = widget.focusScale >= 1.05;
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
