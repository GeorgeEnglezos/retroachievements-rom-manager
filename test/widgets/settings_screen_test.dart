import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/screens/settings_screen.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: child,
      );

  // The Data buttons ("Back up", "Clear all data", …) say what they
  // do but not what it costs, so each one must carry a tooltip. Written as a
  // sweep so a newly added action without one turns this red.
  testWidgets('every Data action carries a tooltip', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump();

    final wrap = find
        .ancestor(of: find.text('Back up'), matching: find.byType(Wrap))
        .first;
    final actions = find.descendant(
      of: wrap,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(actions, findsWidgets);

    for (final element in actions.evaluate()) {
      final label = (element.widget as ButtonStyleButton).child.toString();
      expect(
        find.ancestor(
            of: find.byWidget(element.widget), matching: find.byType(Tooltip)),
        findsOneWidget,
        reason: 'settings action $label has no tooltip',
      );
    }
  });
}
