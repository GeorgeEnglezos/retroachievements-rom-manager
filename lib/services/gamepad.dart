import 'package:gamepads/gamepads.dart' show GamepadButton, GamepadAxis;

/// A semantic controller action, decoupled from which physical button sent it.
///
/// Directions ([up]/[down]/[left]/[right]) are *held* states — the mapper keeps
/// the current one in [GamepadMapper.activeDirection] and the widget layer
/// drives edge-fire + auto-repeat off it. The rest are discrete presses that
/// [GamepadMapper.onButton] returns once, on the press edge.
enum GamepadAction { up, down, left, right, confirm, back }

/// Turns the `gamepads` package's *normalized* button/axis events into
/// [GamepadAction]s. The package's [GamepadNormalizer] already resolves the
/// per-platform, per-controller raw codes into these standard enums, so this
/// layer only adds what it doesn't: an analog dead zone, press-vs-hold-vs-
/// release edges, and held-direction tracking for auto-repeat.
///
/// Pure Dart (the imported symbols are plain enums), so it unit-tests without
/// the plugin channel.
class GamepadMapper {
  /// Stick fraction that counts as "pushed". Below it the axis reads neutral,
  /// so a resting stick's drift doesn't scroll the menu.
  final double deadZone;

  GamepadMapper({this.deadZone = 0.5});

  // Buttons currently held, so a repeated 1.0 sample doesn't re-fire.
  final Set<GamepadButton> _pressed = {};
  // Current zone per axis: -1, 0 or 1.
  final Map<GamepadAxis, int> _axisZone = {};

  GamepadAction? _activeDirection;

  /// The direction currently held (stick past the dead zone, or a dpad button
  /// down), or null when neutral. The widget fires this on change and repeats
  /// it while it stays non-null.
  GamepadAction? get activeDirection => _activeDirection;

  /// Feeds a normalized button event (value 1.0 pressed, 0.0 released).
  /// Returns a discrete action to fire *now* on the press edge, or null.
  /// Dpad presses set [activeDirection] instead of returning.
  GamepadAction? onButton(GamepadButton button, double value) {
    final down = value >= 0.5;
    final wasDown = _pressed.contains(button);
    if (down == wasDown) return null; // no edge
    if (down) {
      _pressed.add(button);
      return _onDown(button);
    }
    _pressed.remove(button);
    _onUp(button);
    return null;
  }

  /// Feeds a normalized stick/dpad axis (sticks -1..1, Left/Down negative,
  /// Right/Up positive). Updates [activeDirection]; never returns an action.
  void onAxis(GamepadAxis axis, double value) {
    final zone = value <= -deadZone ? -1 : (value >= deadZone ? 1 : 0);
    if (_axisZone[axis] == zone) return; // still in the same zone, no edge
    _axisZone[axis] = zone;
    final dir = zone == 0 ? null : _axisDirection(axis, zone);
    if (dir == null) {
      // Released. Only clear if the held direction was this axis's doing.
      if (_activeDirection != null && _axisOwns(axis, _activeDirection!)) {
        _activeDirection = null;
      }
      return;
    }
    _activeDirection = dir;
  }

  static bool _isHorizontal(GamepadAxis axis) =>
      axis == GamepadAxis.leftStickX || axis == GamepadAxis.rightStickX;

  GamepadAction? _axisDirection(GamepadAxis axis, int zone) {
    if (_isHorizontal(axis)) {
      return zone < 0 ? GamepadAction.left : GamepadAction.right;
    }
    // Vertical sticks: +1 is up per the package's convention.
    return zone > 0 ? GamepadAction.up : GamepadAction.down;
  }

  bool _axisOwns(GamepadAxis axis, GamepadAction dir) => _isHorizontal(axis)
      ? (dir == GamepadAction.left || dir == GamepadAction.right)
      : (dir == GamepadAction.up || dir == GamepadAction.down);

  GamepadAction? _onDown(GamepadButton button) {
    // ponytail: two directions held at once → last press wins. Fine for menus.
    switch (button) {
      case GamepadButton.dpadUp:
        return _hold(GamepadAction.up);
      case GamepadButton.dpadDown:
        return _hold(GamepadAction.down);
      case GamepadButton.dpadLeft:
        return _hold(GamepadAction.left);
      case GamepadButton.dpadRight:
        return _hold(GamepadAction.right);
      case GamepadButton.a:
        return GamepadAction.confirm;
      case GamepadButton.b:
        return GamepadAction.back;
      default:
        // Start and the bumpers land here: nothing binds them, so they map to
        // no action rather than dispatching an intent no one handles.
        return null;
    }
  }

  GamepadAction? _hold(GamepadAction dir) {
    _activeDirection = dir;
    return null; // held direction flows through activeDirection, not the return
  }

  void _onUp(GamepadButton button) {
    final dir = switch (button) {
      GamepadButton.dpadUp => GamepadAction.up,
      GamepadButton.dpadDown => GamepadAction.down,
      GamepadButton.dpadLeft => GamepadAction.left,
      GamepadButton.dpadRight => GamepadAction.right,
      _ => null,
    };
    if (dir != null && _activeDirection == dir) _activeDirection = null;
  }
}
