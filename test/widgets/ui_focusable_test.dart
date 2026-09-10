import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/ui/ui_focusable.dart';

Widget _host(Widget child) => MaterialApp(
  theme: uiTheme(UiTokens.light),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('ActivateIntent (gamepad A / Enter) fires onPressed', (t) async {
    var pressed = 0;
    await t.pumpWidget(
      _host(
        UiFocusable(
          borderRadius: BorderRadius.circular(8),
          onPressed: () => pressed++,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );

    // Tab moves focus onto the (only) focusable leaf — the detector — then
    // Enter resolves to ActivateIntent, the same intent the gamepad's A fires.
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle(); // drain the focus tilt animation
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();

    expect(pressed, 1);
  });

  testWidgets('non-interactive (null onPressed) is not focusable', (t) async {
    await t.pumpWidget(
      _host(
        UiFocusable(
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    final detector = findDetector(t);
    expect(detector.enabled, isFalse);
  });
}

FocusableActionDetector findDetector(WidgetTester t) =>
    t.widget<FocusableActionDetector>(find.byType(FocusableActionDetector));
