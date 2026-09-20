import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

import '../services/gamepad.dart';
import '../services/log_service.dart';
import '../theme/ui_tokens.dart';

// Flip to true, rebuild, and press every button to read what your controller
// actually sends into the Logs tab — the way to check a pad the SDL mapping
// database doesn't know. Left off so normal runs don't spam the log.
const bool _logRawInput = false;

const _initialRepeatDelay = Duration(milliseconds: 400);
const _repeatInterval = Duration(milliseconds: 110);

/// Drives Flutter's focus system from a game controller.
///
/// Wraps the app once (below `MaterialApp`, so its default `Actions` are in
/// scope). It listens to the `gamepads` stream, normalizes it to standard
/// buttons/axes, feeds [GamepadMapper], and turns the result into ordinary
/// focus moves + activation — so every existing focusable widget (InkWell,
/// buttons, list tiles) is controller-navigable with no per-screen work.
class GamepadNavigator extends StatefulWidget {
  final Widget child;
  const GamepadNavigator({super.key, required this.child});

  @override
  State<GamepadNavigator> createState() => _GamepadNavigatorState();
}

class _GamepadNavigatorState extends State<GamepadNavigator> {
  final _mapper = GamepadMapper();
  final _normalizer = GamepadNormalizer();
  StreamSubscription<NormalizedGamepadEvent>? _sub;
  Timer? _repeatTimer;
  Timer? _connectPoll;
  GamepadAction? _heldDirection;
  // Whether at least one controller is connected, from the last poll. Drives the
  // hint footer; the plugin has no connect/disconnect event, so we poll for it.
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        !(Platform.isAndroid ||
            Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS)) {
      return; // no gamepad plugin on this platform
    }
    try {
      _sub = Gamepads.events
          .transform(_normalizer.transformer)
          .listen(_onEvent);
      // ponytail: the plugin has no connect/disconnect event, so poll the list.
      // 1.5s is well under human patience for "I plugged in my pad".
      _connectPoll =
          Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollPads());
      _pollPads();
    } catch (e) {
      // No plugin registered (e.g. under widget tests) — input just stays off.
      LogService.debug('Gamepad', 'events unavailable: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _repeatTimer?.cancel();
    _connectPoll?.cancel();
    super.dispose();
  }

  // Track whether any controller is connected, so the hint footer shows only
  // when one is. Connecting a pad no longer switches modes; it just works in
  // whichever mode the app is in.
  Future<void> _pollPads() async {
    final int count;
    try {
      count = (await Gamepads.list()).length;
    } catch (_) {
      return; // listing failed; leave the last-known state alone
    }
    if (!mounted) return;
    final connected = count > 0;
    if (connected != _connected) setState(() => _connected = connected);
  }

  void _onEvent(NormalizedGamepadEvent e) {
    if (_logRawInput) LogService.debug('Gamepad', e.toString());
    final button = e.button;
    if (button != null) {
      final action = _mapper.onButton(button, e.value);
      if (action != null) _dispatchDiscrete(action);
    } else if (e.axis != null) {
      _mapper.onAxis(e.axis!, e.value);
    }
    _reconcileDirection();
  }

  // Fire the held direction on change, then repeat it while it stays held —
  // the auto-repeat the mapper deliberately leaves to the widget layer.
  void _reconcileDirection() {
    final dir = _mapper.activeDirection;
    if (dir == _heldDirection) return;
    _heldDirection = dir;
    _repeatTimer?.cancel();
    if (dir == null) return;
    _fireDirection(dir);
    _repeatTimer = Timer(_initialRepeatDelay, () {
      _fireDirection(dir);
      _repeatTimer = Timer.periodic(_repeatInterval, (_) => _fireDirection(dir));
    });
  }

  void _dispatchDiscrete(GamepadAction action) {
    switch (action) {
      case GamepadAction.confirm:
        _invoke(const ActivateIntent());
      case GamepadAction.back:
        _back();
      case GamepadAction.up:
      case GamepadAction.down:
      case GamepadAction.left:
      case GamepadAction.right:
        break;
    }
  }

  void _fireDirection(GamepadAction dir) {
    if (!mounted) return;
    final t = switch (dir) {
      GamepadAction.up => TraversalDirection.up,
      GamepadAction.down => TraversalDirection.down,
      GamepadAction.left => TraversalDirection.left,
      GamepadAction.right => TraversalDirection.right,
      _ => null,
    };
    if (t == null) return;
    final primary = FocusManager.instance.primaryFocus;
    // Nothing meaningful focused yet (idle app rests on the root scope): seed
    // focus into the page instead of moving from nowhere.
    if (primary == null || primary == FocusManager.instance.rootScope) {
      FocusManager.instance.rootScope.nextFocus();
      return;
    }
    primary.focusInDirection(t);
  }

  // Dispatch an intent at whatever is focused, so a shell ancestor's Actions can
  // handle it. No focus yet (idle root scope) means nothing to invoke on.
  void _invoke(Intent intent) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null) Actions.maybeInvoke(ctx, intent);
  }

  void _back() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_connected) return widget.child;
    // A controller is plugged in: keep the app exactly as it is and add a
    // persistent hint strip along the bottom so the pad controls are discoverable
    // in any mode.
    return Column(
      children: [
        Expanded(child: widget.child),
        const _GamepadFooter(),
      ],
    );
  }
}

/// The controller-hint strip shown at the bottom while a pad is connected. Sits
/// above `MaterialApp`'s route content, so it carries no Material ancestor: every
/// bit of text sets its own style from the theme tokens.
class _GamepadFooter extends StatelessWidget {
  const _GamepadFooter();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.surface,
        border: Border(top: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Hint(glyph: '↕↔', label: 'Navigate'),
              SizedBox(width: 20),
              _Hint(glyph: 'A', label: 'Select'),
              SizedBox(width: 20),
              _Hint(glyph: 'B', label: 'Back'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String glyph;
  final String label;
  const _Hint({required this.glyph, required this.label});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ui.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: ui.border, width: ui.borderWidth),
          ),
          child: Text(glyph,
              style: ui.labelCaps.copyWith(fontSize: 11, letterSpacing: 0)),
        ),
        const SizedBox(width: 6),
        Text(label, style: ui.body.copyWith(color: ui.muted)),
      ],
    );
  }
}
