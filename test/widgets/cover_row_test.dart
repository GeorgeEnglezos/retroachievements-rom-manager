import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/bigpicture/cover_row.dart';

// Art left null so tiles render their placeholder, never a network image.
RomResult _g(String path, String title) =>
    RomResult(filePath: path, fileName: '$title.sfc')..gameTitle = title;

void main() {
  testWidgets('renders one tile per game and reports the opened rom',
      (tester) async {
    RomResult? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: [_g('/a.sfc', 'Alpha'), _g('/b.sfc', 'Beta')],
          onOpen: (r) => opened = r,
        ),
      ),
    ));

    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    expect(opened?.filePath, '/a.sfc');
  });

  testWidgets('an empty row renders nothing (no header)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CoverRow(title: 'Jump back in', games: [], onOpen: _noop),
      ),
    ));
    expect(find.text('Jump back in'), findsNothing);
  });

  testWidgets('spare width grows the tiles instead of leaving it blank',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: [_g('/a.sfc', 'Alpha'), _g('/b.sfc', 'Beta')],
          onOpen: _noop,
          tileSize: 100,
        ),
      ),
    ));

    final tile = tester.widget<CoverTile>(find.byType(CoverTile).first);
    expect(tile.size, greaterThan(100));
  });

  testWidgets('a narrow row keeps the base tile size and scrolls instead',
      (tester) async {
    tester.view.physicalSize = const Size(300, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: [_g('/a.sfc', 'Alpha'), _g('/b.sfc', 'Beta')],
          onOpen: _noop,
          tileSize: 160,
        ),
      ),
    ));

    final tile = tester.widget<CoverTile>(find.byType(CoverTile).first);
    expect(tile.size, 160);
  });

  testWidgets(
      'compact (the fitted desktop layout) never grows past tileSize, even '
      'with spare width', (tester) async {
    // couchFillTileSize already sizes tileSize to fill every row's shared
    // height budget; a second, per-row width-driven grow would break that
    // budget for rows with fewer games. compact:true is the fitted layout's
    // signal that tileSize is already final.
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: [_g('/a.sfc', 'Alpha'), _g('/b.sfc', 'Beta')],
          onOpen: _noop,
          tileSize: 100,
          compact: true,
        ),
      ),
    ));

    final tile = tester.widget<CoverTile>(find.byType(CoverTile).first);
    expect(tile.size, 100);
  });

  testWidgets('never shows more than 10 tiles even with room to spare',
      (tester) async {
    // A real, wide test surface (not just a wide SizedBox inside the default
    // 800px one) so the grown row's whole content is actually on screen and
    // ListView.builder has no reason to lazily skip building any of it.
    tester.view.physicalSize = const Size(3000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final games = [for (var i = 0; i < 15; i++) _g('/$i.sfc', 'Game $i')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: games,
          onOpen: _noop,
          tileSize: 100,
        ),
      ),
    ));

    expect(find.byType(CoverTile), findsNWidgets(10));
  });
}

void _noop(RomResult _) {}
