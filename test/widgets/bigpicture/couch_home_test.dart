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

  group('couchFillTileWidth', () {
    test('a wider row grows the tiles', () {
      expect(CouchHome.couchFillTileWidth(1600),
          greaterThan(CouchHome.couchFillTileWidth(1100)));
    });

    test('a narrow window bottoms out at the floor', () {
      // Too narrow to give six covers room: clamps to the minimum, the same
      // size the compact layout uses.
      expect(CouchHome.couchFillTileWidth(400),
          CouchHome.couchFillTileWidth(100));
    });

    test('a very wide window stops growing at the ceiling', () {
      expect(CouchHome.couchFillTileWidth(5000),
          CouchHome.couchFillTileWidth(3000));
    });

    // UiZoom hands a zoomed-in layout a viewport shrunk by the scale, then
    // paints the result back up by it. Sizing from the logical width alone let
    // the fixed tile chrome eat the difference, so covers came out smaller the
    // further you zoomed in; they have to grow with the zoom like everything
    // else in the app.
    test('zoom grows covers instead of shrinking them', () {
      const width = 1400.0;
      final at100 = CouchHome.couchFillTileWidth(width);
      final at125 = CouchHome.couchFillTileWidth(width / 1.25, scale: 1.25) * 1.25;
      expect(at125, closeTo(at100 * 1.25, 0.01));
    });

    test('a normal window lands strictly between floor and ceiling', () {
      final mid = CouchHome.couchFillTileWidth(1400);
      expect(mid, greaterThan(CouchHome.couchFillTileWidth(400)));
      expect(mid, lessThan(CouchHome.couchFillTileWidth(5000)));
    });
  });
}
