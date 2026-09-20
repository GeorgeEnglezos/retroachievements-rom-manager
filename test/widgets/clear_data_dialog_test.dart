import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/data_wipe.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/clear_data_dialog.dart';

import '../support/fixtures.dart';

void main() {
  Set<ClearTarget>? result;
  var returned = false;

  /// Opens the dialog and records what it returns. [size] overrides the
  /// default desktop surface.
  Future<void> open(WidgetTester tester, {Size? size}) async {
    if (size == null) {
      useDesktopViewport(tester);
    } else {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    result = null;
    returned = false;
    await tester.pumpWidget(MaterialApp(
      theme: uiTheme(UiTokens.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showClearDataDialog(context);
              returned = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder tile(String label) => find.widgetWithText(CheckboxListTile, label);

  /// The list scrolls, so a row further down has to be brought into view
  /// before it can be tapped.
  Future<void> tapTile(WidgetTester tester, String label) async {
    await tester.ensureVisible(tile(label));
    await tester.pumpAndSettle();
    await tester.tap(tile(label));
    await tester.pump();
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TextButton, label));
    await tester.pumpAndSettle();
  }

  TextButton action(WidgetTester tester, String label) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, label));

  bool ticked(WidgetTester tester, String label) =>
      tester.widget<CheckboxListTile>(tile(label)).value == true;

  bool locked(WidgetTester tester, String label) =>
      tester.widget<CheckboxListTile>(tile(label)).onChanged == null;

  // The dialog only deletes, so it must open unable to do anything.
  testWidgets('Delete is disabled until something is ticked', (tester) async {
    await open(tester);

    expect(action(tester, 'Delete').onPressed, isNull);

    await tapTile(tester, 'Cached artwork');

    expect(action(tester, 'Delete').onPressed, isNotNull);
  });

  // A trash or favorite verdict files the game in the matching playlist, so
  // the two can't be separated. The row has to say so rather than let the
  // user tick a combination the wipe will silently override.
  testWidgets('picking playlists ticks and locks cull verdicts',
      (tester) async {
    await open(tester);
    expect(ticked(tester, 'Cull verdicts'), isFalse);
    expect(locked(tester, 'Cull verdicts'), isFalse);

    await tapTile(tester, 'Playlists and favorite systems');

    expect(ticked(tester, 'Cull verdicts'), isTrue);
    expect(locked(tester, 'Cull verdicts'), isTrue);

    await tapAction(tester, 'Delete');

    expect(result, containsAll([ClearTarget.playlists, ClearTarget.cullVerdicts]));
  });

  // The reverse is allowed: replay the elimination game without losing the
  // playlists it filed things into.
  testWidgets('cull verdicts can be cleared on their own', (tester) async {
    await open(tester);

    await tapTile(tester, 'Cull verdicts');
    await tapAction(tester, 'Delete');

    expect(result, {ClearTarget.cullVerdicts});
  });

  testWidgets('Everything selects every target', (tester) async {
    await open(tester);

    await tapTile(tester, 'Everything');
    await tapAction(tester, 'Delete');

    expect(result, ClearTarget.values.toSet());
  });

  // The cost lines need a readable measure, not the whole monitor: without a
  // cap the dialog stretches to the window, and with a fixed width it
  // overflows a phone. Asserted as a relationship so retuning the cap is free.
  testWidgets('the dialog is capped wide and shrinks on a narrow window',
      (tester) async {
    double width() => tester.getSize(find.byKey(clearDataContentKey)).width;
    Future<void> resize(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
    }

    await open(tester, size: const Size(1400, 1000));
    final wide = width();

    await resize(const Size(900, 1000));
    expect(width(), wide, reason: 'a wider window must not widen the dialog');

    // A phone: narrower than the cap, and rendering at all means nothing
    // overflowed (the test binding fails on overflow).
    await resize(const Size(400, 800));
    expect(width(), lessThan(400));
  });

  testWidgets('cancelling returns null, not an empty selection',
      (tester) async {
    await open(tester);

    await tapTile(tester, 'Scan results');
    await tapAction(tester, 'Cancel');

    expect(returned, isTrue);
    expect(result, isNull);
  });
}
