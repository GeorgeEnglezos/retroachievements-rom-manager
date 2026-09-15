import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_group.dart';
import 'package:rarm/models/rom_row.dart';
import 'package:rarm/services/member_key.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/widgets/row_display.dart';
import 'package:rarm/widgets/rom_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

RomRow _row(String path) => RomRow(title: path, filePath: path);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bulk favorites toggles the selected rows and notifies',
      (tester) async {
    useDesktopViewport(tester);
    final store = PlaylistStore();
    var playlistChanged = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomListView(
          rows: [_row('a'), _row('b')],
          display: RowDisplay.roms,
          store: store,
          enableSelection: true,
          initialSelected: const {'a', 'b'},
          bulkFavorites: true,
          onPlaylistChanged: () => playlistChanged++,
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(store.isFavorite(memberKeyFor(gameId: null, filePath: 'a')), isTrue);
    expect(store.isFavorite(memberKeyFor(gameId: null, filePath: 'b')), isTrue);
    expect(playlistChanged, 1);
    expect(find.text('Added 2 to Favorites'), findsOneWidget);
  });

  testWidgets('unsupported bulk actions hide their buttons', (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomListView(
          rows: [_row('a')],
          display: RowDisplay.roms,
          store: PlaylistStore(),
          enableSelection: true,
          initialSelected: const {'a'},
        ),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.playlist_add), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets("leadings render one icon per row, in the tile's art slot",
      (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomListView(
          rows: [_row('a'), _row('b')],
          display: RowDisplay.storage,
          store: PlaylistStore(),
          // Second entry null: that row must fall back to its own art rather
          // than range-error.
          leadings: const [Icon(Icons.videogame_asset), null],
        ),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.videogame_asset), findsOneWidget);
  });

  testWidgets(
      'delete runs each selected row through onDeleteRow and reports only the gone ones',
      (tester) async {
    useDesktopViewport(tester);

    final rows = [_row('a'), _row('b'), _row('c')];
    final deleted = <String>[];
    List<RomRow>? removed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomListView(
          rows: rows,
          display: RowDisplay.roms,
          store: PlaylistStore(),
          enableSelection: true,
          initialSelected: const {'a', 'b', 'c'},
          onDeleteRow: (r) async {
            deleted.add(r.filePath!);
            return r.filePath != 'b'; // 'b' fails
          },
          onRowsRemoved: (r) => removed = r,
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline)); // bulk bar Delete
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last); // confirm dialog
    await tester.pumpAndSettle();

    expect(deleted, ['a', 'b', 'c']);
    expect(removed!.map((r) => r.filePath), ['a', 'c']);
  });

  testWidgets('a group header collapses and re-expands only its own rows',
      (tester) async {
    useDesktopViewport(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomListView(
          groups: [
            RomGroup(label: 'SNES', rows: [_row('a')]),
            RomGroup(label: 'NES', rows: [_row('b')]),
          ],
          display: RowDisplay.roms,
          store: PlaylistStore(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('a'), findsOneWidget);

    await tester.tap(find.text('SNES'));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
    expect(find.text('b'), findsOneWidget);

    await tester.tap(find.text('SNES'));
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget);
  });

  group('gridColumns', () {
    test('caps tile width at the target, adding a column as width grows', () {
      // 4*150 + 3*10 gaps = 630 fits 4 columns exactly at the target width...
      expect(gridColumns(630, 150, 10), 4);
      // ...a hair under still gives 4 (tiles a touch narrower than target)...
      expect(gridColumns(629, 150, 10), 4);
      // ...and a hair over adds a fifth (tiles shrink below the target),
      // matching maxCrossAxisExtent's cap-the-width behaviour.
      expect(gridColumns(631, 150, 10), 5);
    });

    test('the derived tile width never exceeds the target', () {
      const width = 800.0, target = 150.0, spacing = 10.0;
      final cols = gridColumns(width, target, spacing);
      final tileW = (width - spacing * (cols - 1)) / cols;
      expect(tileW, lessThanOrEqualTo(target));
    });

    test('never drops below one column, even below one tile wide', () {
      expect(gridColumns(80, 150, 10), 1);
      expect(gridColumns(0, 150, 10), 1);
    });

    test('guards against a non-positive target', () {
      expect(gridColumns(800, 0, 10), 1);
    });
  });
}
