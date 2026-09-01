import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/bulk_action_bar.dart';

import '../support/fixtures.dart';

void main() {
  testWidgets('shows count and fires action callbacks', (tester) async {
    useDesktopViewport(tester);
    var fav = false, del = false, closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BulkActionBar(
          selectedCount: 3,
          deleting: false,
          deleteDone: 0,
          deleteTotal: 0,
          onFavorites: () => fav = true,
          onPlaylist: () {},
          onDelete: () => del = true,
          onExclude: () {},
          onClose: () => closed = true,
        ),
      ),
    ));
    expect(find.text('3 selected'), findsOneWidget);
    await tester.tap(find.text('Favorites'));
    await tester.tap(find.text('Delete'));
    await tester.tap(find.byIcon(Icons.close));
    expect(fav && del && closed, isTrue);
  });

  testWidgets('close carries an accessible name', (tester) async {
    // Every other button on the bar has visible text to name it; close is the
    // one bare icon, so its tooltip is the only thing naming it for a screen
    // reader. Asserted on the Tooltip rather than via find.bySemanticsLabel,
    // which does not match a tooltip's message node.
    useDesktopViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BulkActionBar(
          selectedCount: 1,
          deleting: false,
          deleteDone: 0,
          deleteTotal: 0,
          onDelete: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(
      find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Clear selection'),
      findsOneWidget,
    );
  });

  testWidgets('shows progress while deleting', (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BulkActionBar(
          selectedCount: 0,
          deleting: true,
          deleteDone: 2,
          deleteTotal: 5,
          onFavorites: () {},
          onPlaylist: () {},
          onDelete: () {},
          onExclude: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('Deleting 2 of 5…'), findsOneWidget);
  });
}
