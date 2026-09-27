import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/widgets/playlist_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().clear();
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('Played and Want to Play checkboxes are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(PlaylistPicker(store: PlaylistStore(), memberKey: 'ra:1')),
    );
    await tester.pumpAndSettle();

    final played = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Played'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(played.onChanged, isNull);

    final wantToPlay = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Want to Play'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(wantToPlay.onChanged, isNull);
  });

  testWidgets('Favorites checkbox stays enabled', (tester) async {
    await tester.pumpWidget(
      host(PlaylistPicker(store: PlaylistStore(), memberKey: 'ra:1')),
    );
    await tester.pumpAndSettle();

    final favorites = tester.widget<CheckboxListTile>(
      find.ancestor(
        of: find.text('Favorites'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    expect(favorites.onChanged, isNotNull);
  });

  testWidgets('bulk picker disables Played and Want to Play tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () =>
                  PlaylistPicker.showBulk(context, PlaylistStore(), ['ra:1']),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final played = tester.widget<ListTile>(
      find.ancestor(of: find.text('Played'), matching: find.byType(ListTile)),
    );
    expect(played.enabled, isFalse);

    final wantToPlay = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Want to Play'),
        matching: find.byType(ListTile),
      ),
    );
    expect(wantToPlay.enabled, isFalse);

    final favorites = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Favorites'),
        matching: find.byType(ListTile),
      ),
    );
    expect(favorites.enabled, isTrue);
  });
}
