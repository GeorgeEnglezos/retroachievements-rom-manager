import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/dashboard_cover.dart';
import 'package:rarm/widgets/dashboard_sections.dart';

// boxArt left null so the cover renders its placeholder (no network image).
RomResult _g(String path, String title, {int total = 10, int earned = 0}) =>
    RomResult(filePath: path, fileName: '$title.sfc')
      ..status = RomStatus.supported
      ..gameTitle = title
      ..consoleName = 'SNES'
      ..achievementCount = total
      ..earnedAchievements = earned;

final _games = [
  _g('/a.sfc', 'Alpha', earned: 3),
  _g('/b.sfc', 'Beta', earned: 0),
];

void main() {
  testWidgets('renders one cover per game and reports the tapped rom',
      (tester) async {
    RomResult? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: DashboardCoverSection(
            title: 'Jump back in',
            games: _games,
            onOpen: (r) => tapped = r,
          ),
        ),
      ),
    ));

    expect(find.byType(DashboardCover), findsNWidgets(2));
    expect(find.text('3/10'), findsOneWidget); // per-cover achievement line

    await tester.tap(find.byType(DashboardCover).first);
    expect(tapped?.filePath, '/a.sfc');
  });

  testWidgets('fills the width with square cells and shows no more than fit',
      (tester) async {
    final many = [for (var i = 0; i < 12; i++) _g('/$i.sfc', 'Game $i')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: DashboardCoverSection(
            title: 'Jump back in',
            games: many,
            onOpen: (_) {},
          ),
        ),
      ),
    ));

    // 700 wide at the 168 minimum, 12px gaps: 3 columns, one row (a 4th
    // would push each cell under the minimum).
    expect(find.byType(DashboardCover), findsNWidgets(3));
    final tile = tester.getSize(find.byType(DashboardCover).first);
    expect(tile.width, closeTo((700 - 12 * 2) / 3, 0.1));
  });

  testWidgets('a narrow window drops to fewer columns', (tester) async {
    final many = [for (var i = 0; i < 12; i++) _g('/$i.sfc', 'Game $i')];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 358,
          child: DashboardCoverSection(
            title: 'Jump back in',
            games: many,
            onOpen: (_) {},
          ),
        ),
      ),
    ));

    expect(find.byType(DashboardCover), findsNWidgets(2));
  });

  testWidgets('renders nothing when the bucket is empty', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body:
            DashboardCoverSection(title: 'Empty', games: const [], onOpen: (_) {}),
      ),
    ));

    expect(find.text('Empty'), findsNothing);
    expect(find.byType(DashboardCover), findsNothing);
  });

  group('phone layouts', () {
    testWidgets('list section caps the rows it shows and reports taps',
        (tester) async {
      RomResult? tapped;
      final many = [for (var i = 0; i < 9; i++) _g('/$i.sfc', 'Game $i')];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardListSection(
            title: 'Jump back in',
            games: many,
            onOpen: (r) => tapped = r,
          ),
        ),
      ));

      expect(find.text('Game 0'), findsOneWidget);
      expect(find.text('Game 5'), findsOneWidget);
      expect(find.text('Game 6'), findsNothing); // max 6

      await tester.tap(find.text('Game 1'));
      expect(tapped?.filePath, '/1.sfc');
    });

    testWidgets('a pinned column count fills the row width in equal columns',
        (tester) async {
      final many = [for (var i = 0; i < 9; i++) _g('/$i.sfc', 'Game $i')];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: DashboardCoverSection(
              title: 'Popular',
              games: many,
              onOpen: (_) {},
              columns: 3,
              rows: 2,
            ),
          ),
        ),
      ));

      expect(find.byType(DashboardCover), findsNWidgets(6)); // 3 x 2
      // 3 columns, 12px gaps: (358 - 24) / 3.
      // Fixed cells: a placeholder or a wide box-art fallback must not
      // narrow a column and break the grid.
      final tile = tester.getSize(find.byType(DashboardCover).first);
      expect(tile.width, closeTo(111.33, 0.1));
    });
  });
}
