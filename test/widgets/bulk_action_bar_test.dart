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
