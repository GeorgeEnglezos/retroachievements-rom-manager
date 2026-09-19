import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/home_dashboard.dart';
import 'package:rarm/widgets/bigpicture/couch_home.dart';
import 'package:rarm/widgets/bigpicture/couch_hero.dart';

RomResult _g(String path, String title) =>
    RomResult(filePath: path, fileName: '$title.sfc')..gameTitle = title;

HomeDashboard _dashboardWithBothHeroes() => HomeDashboard(
      spotlight: _g('/a.sfc', 'Alpha'),
      beatSpotlight: _g('/b.sfc', 'Beta'),
      continuePlaying: const [],
      closestToMastery: const [],
      popularUnplayed: const [],
      stats: DashboardStats.empty,
    );

void main() {
  group('CouchHome hero banners', () {
    Widget app() => MaterialApp(
          home: Scaffold(
            body: CouchHome(
              dashboard: _dashboardWithBothHeroes(),
              onOpen: (_) {},
              onIgnore: (_) {},
            ),
          ),
        );

    testWidgets('stack vertically on a phone-width screen', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());

      final heroes = find.byType(CouchHero);
      expect(heroes, findsNWidgets(2));
      final beatCenter = tester.getCenter(heroes.first);
      final masteryCenter = tester.getCenter(heroes.last);
      expect(beatCenter.dx, masteryCenter.dx);
      expect(beatCenter.dy, lessThan(masteryCenter.dy));
    });

    testWidgets('stay side by side on a wider compact screen',
        (tester) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());

      final heroes = find.byType(CouchHero);
      expect(heroes, findsNWidgets(2));
      final beatCenter = tester.getCenter(heroes.first);
      final masteryCenter = tester.getCenter(heroes.last);
      expect(beatCenter.dy, masteryCenter.dy);
      expect(beatCenter.dx, lessThan(masteryCenter.dx));
    });
  });

  group('couchFillTileSize', () {
    test('a taller column grows the tiles', () {
      expect(CouchHome.couchFillTileSize(1200, 3),
          greaterThan(CouchHome.couchFillTileSize(900, 3)));
    });

    test('a short window bottoms out at the floor, like an unknown row count',
        () {
      // Too short to give three rows room: clamps to the minimum, the same
      // size the compact layout uses (rowCount 0 short-circuits to it).
      expect(CouchHome.couchFillTileSize(300, 3),
          CouchHome.couchFillTileSize(999, 0));
    });

    test('a very tall window stops growing at the ceiling', () {
      expect(CouchHome.couchFillTileSize(5000, 3),
          CouchHome.couchFillTileSize(3000, 3));
    });

    // UiZoom hands a zoomed-in layout a viewport shrunk by the scale, then
    // paints the result back up by it. Sizing from the logical height alone let
    // the fixed row chrome eat the difference, so covers came out smaller the
    // further you zoomed in; they have to grow with the zoom like everything
    // else in the app.
    test('zoom grows covers instead of shrinking them', () {
      const height = 900.0;
      final at100 = CouchHome.couchFillTileSize(height, 3);
      final at125 =
          CouchHome.couchFillTileSize(height / 1.25, 3, scale: 1.25) * 1.25;
      expect(at125, closeTo(at100 * 1.25, 0.01));
    });

    test('a normal window lands strictly between floor and ceiling', () {
      final mid = CouchHome.couchFillTileSize(900, 3);
      expect(mid, greaterThan(CouchHome.couchFillTileSize(300, 3)));
      expect(mid, lessThan(CouchHome.couchFillTileSize(5000, 3)));
    });
  });
}
