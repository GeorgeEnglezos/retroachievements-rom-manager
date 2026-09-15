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

  testWidgets('a lifted surface (focusScale > 1.0) renders the drop shadow '
      'by default', (t) async {
    await t.pumpWidget(
      _host(
        UiFocusable(
          borderRadius: BorderRadius.circular(8),
          onPressed: () {},
          focusScale: 1.08,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(shadowBoxes(), findsOneWidget);
  });

  testWidgets('showShadow:false drops the shadow even when lifted', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        UiFocusable(
          borderRadius: BorderRadius.circular(8),
          onPressed: () {},
          focusScale: 1.08,
          showShadow: false,
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(shadowBoxes(), findsNothing);
  });

  testWidgets('hover still lights the surface (ring/zoom unaffected)', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        UiFocusable(
          borderRadius: BorderRadius.circular(8),
          onPressed: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(findDetector(t).onShowHoverHighlight, isNotNull);
  });

  testWidgets('passes tight parent constraints through to child', (t) async {
    await t.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          height: 150,
          child: UiFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(width: 30, height: 30),
              ],
            ),
          ),
        ),
      ),
    );
    final renderBox = t.renderObject<RenderBox>(find.byType(Column));
    expect(renderBox.size.width, 200);
    expect(renderBox.size.height, 150);
  });
}

FocusableActionDetector findDetector(WidgetTester t) =>
    t.widget<FocusableActionDetector>(find.byType(FocusableActionDetector));

Finder shadowBoxes() => find.byWidgetPredicate((w) =>
    w is DecoratedBox &&
    (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true);
