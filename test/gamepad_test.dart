import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart' show GamepadButton, GamepadAxis;
import 'package:rarm/services/gamepad.dart';

GamepadMapper _mapper() => GamepadMapper(deadZone: 0.5);

void main() {
  group('analog direction', () {
    test('inside the dead zone stays neutral', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickX, 0.3);
      expect(m.activeDirection, isNull);
    });

    test('past the dead zone activates a direction', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickX, 0.7);
      expect(m.activeDirection, GamepadAction.right);
      m.onAxis(GamepadAxis.leftStickX, -0.7);
      expect(m.activeDirection, GamepadAction.left);
    });

    test('holding the same zone does not clear or flip the direction', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickX, 0.7);
      m.onAxis(GamepadAxis.leftStickX, 0.9); // still right
      expect(m.activeDirection, GamepadAction.right);
    });

    test('returning to centre clears the held direction', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickX, 0.7);
      m.onAxis(GamepadAxis.leftStickX, 0.1);
      expect(m.activeDirection, isNull);
    });

    test('vertical stick: positive is up, negative is down', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickY, 0.9);
      expect(m.activeDirection, GamepadAction.up);
      m.onAxis(GamepadAxis.leftStickY, -0.9);
      expect(m.activeDirection, GamepadAction.down);
    });

    test('centring an axis only clears a direction it owns', () {
      final m = _mapper();
      m.onAxis(GamepadAxis.leftStickX, 0.7); // right
      m.onAxis(GamepadAxis.leftStickY, 0.0); // Y centre must not clear right
      expect(m.activeDirection, GamepadAction.right);
    });
  });

  group('dpad buttons', () {
    test('press holds a direction, release clears it', () {
      final m = _mapper();
      expect(m.onButton(GamepadButton.dpadUp, 1.0), isNull);
      expect(m.activeDirection, GamepadAction.up);
      m.onButton(GamepadButton.dpadUp, 0.0);
      expect(m.activeDirection, isNull);
    });
  });

  group('action buttons', () {
    test('a press edge fires once, hold and release do not repeat', () {
      final m = _mapper();
      expect(m.onButton(GamepadButton.a, 1.0), GamepadAction.confirm);
      expect(m.onButton(GamepadButton.a, 1.0), isNull); // still held
      expect(m.onButton(GamepadButton.a, 0.0), isNull); // released
    });

    test('b, start and shoulder bumpers map', () {
      final m = _mapper();
      expect(m.onButton(GamepadButton.b, 1.0), GamepadAction.back);
      expect(m.onButton(GamepadButton.start, 1.0), GamepadAction.menu);
      expect(m.onButton(GamepadButton.leftBumper, 1.0), GamepadAction.tabLeft);
      expect(m.onButton(GamepadButton.rightBumper, 1.0), GamepadAction.tabRight);
    });

    test('an unmapped button is ignored, not crashed', () {
      final m = _mapper();
      expect(m.onButton(GamepadButton.touchpad, 1.0), isNull);
      expect(m.activeDirection, isNull);
    });
  });
}
