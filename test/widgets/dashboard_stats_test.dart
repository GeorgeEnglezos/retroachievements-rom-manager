import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/home_dashboard.dart';
import 'package:rarm/widgets/dashboard_stats.dart';

const _stats = DashboardStats(
  totalGames: 1287,
  systems: 177,
  mastered: 0,
  achievementsEarned: 267,
  totalSizeBytes: 729000000000,
);

Future<void> _pump(WidgetTester tester,
        {required bool narrow, double width = 358}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: DashboardStatStrip(stats: _stats, narrow: narrow),
        ),
      ),
    ));

void main() {
  testWidgets('phone layout locks the tiles to two equal columns',
      (tester) async {
    await _pump(tester, narrow: true);

    final tiles = tester
        .widgetList<DashboardStatTile>(find.byType(DashboardStatTile))
        .toList();
    expect(tiles.length, 5);

    final first = tester.getSize(find.byType(DashboardStatTile).at(0));
    final second = tester.getSize(find.byType(DashboardStatTile).at(1));
    expect(first.width, second.width);
    expect(first.width, lessThan(358 / 2));

    // Five tiles in two columns: the last one spans the row instead of
    // leaving a half-empty line.
    expect(tester.getSize(find.byType(DashboardStatTile).at(4)).width, 358);
  });

  testWidgets('wide layout lets tiles size to their content', (tester) async {
    await _pump(tester, narrow: false, width: 900);

    final games = tester.getSize(find.byType(DashboardStatTile).at(0));
    final achievements = tester.getSize(find.byType(DashboardStatTile).at(2));
    // 'Achievements earned' is a longer label than 'Games', so its tile is
    // wider; equal widths would mean the narrow branch leaked.
    expect(achievements.width, greaterThan(games.width));
  });
}
