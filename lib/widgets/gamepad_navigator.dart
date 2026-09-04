import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:gamepads/gamepads.dart';

import '../services/gamepad.dart';
import '../services/log_service.dart';

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
  GamepadAction? _heldDirection;

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
    } catch (e) {
      // No plugin registered (e.g. under widget tests) — input just stays off.
      LogService.debug('Gamepad', 'events unavailable: $e');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
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
        _activate();
      case GamepadAction.back:
        _back();
      // menu + shoulder tabs are wired to the couch shell in phase 2.
      case GamepadAction.menu:
      case GamepadAction.tabLeft:
      case GamepadAction.tabRight:
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

  void _activate() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null) Actions.maybeInvoke(ctx, const ActivateIntent());
  }

  void _back() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
