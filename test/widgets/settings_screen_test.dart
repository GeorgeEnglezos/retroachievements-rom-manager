import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/screens/settings_screen.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: child,
      );

  // The Data buttons ("Create Data Backup", "Delete Data", …) say what they
  // do but not what it costs, so each one must carry a tooltip. Written as a
  // sweep so a newly added action without one turns this red.
  testWidgets('every Data action carries a tooltip', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump();

    final wrap = find
        .ancestor(of: find.text('Create Data Backup'), matching: find.byType(Wrap))
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

  // Backup, restore and delete sit together; the wizard stands apart.
  testWidgets('Data tab groups the data actions', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump();

    final wrap = find
        .ancestor(of: find.text('Create Data Backup'), matching: find.byType(Wrap))
        .first;
    for (final label in ['Restore Data Backup', 'Delete Data']) {
      expect(find.descendant(of: wrap, matching: find.text(label)),
          findsOneWidget);
    }
    expect(find.descendant(of: wrap, matching: find.text('Setup Wizard')),
        findsNothing);
    expect(find.text('Setup Wizard'), findsOneWidget);
    expect(find.textContaining('Import scraped'), findsNothing);
    expect(find.text('Remove missing systems'), findsNothing);
  });

  // Kiosk listing options only mean something in Kiosk, so they sit under
  // the mode picker and appear only once Kiosk is chosen.
  testWidgets('kiosk listings show only in Kiosk mode', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => appModeListenable.save(AppMode.cleaning));

    await tester.pumpWidget(host(const SettingsScreen()));
    await tester.pump();
    expect(find.text('Kiosk listings'), findsNothing);

    await tester.tap(find.text('Kiosk'));
    await tester.pump();
    expect(find.text('Kiosk listings'), findsOneWidget);
  });
}
