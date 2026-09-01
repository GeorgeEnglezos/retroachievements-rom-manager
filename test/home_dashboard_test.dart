import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/home_index.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/home_dashboard.dart';
import 'package:rarm/services/ra_service.dart';

RomResult _game(
  String path, {
  int total = 0,
  int earned = 0,
  int players = 0,
  int hardcore = 0,
  String? title,
  DateTime? lastPlayed,
  RaAward? award,
}) {
  return RomResult(filePath: path, fileName: p.basename(path))
    ..status = RomStatus.supported
    ..gameTitle = title
    ..consoleName = 'SNES'
    ..achievementCount = total
    ..earnedAchievements = earned
    ..earnedHardcore = hardcore
    ..numPlayersCasual = players
    ..lastPlayed = lastPlayed
    ..highestAward = award;
}

void main() {
  test('spotlight is the highest-completion in-progress game', () {
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 2), // 20%
      _game('/b.sfc', total: 10, earned: 9), // 90%
    ]);
    expect(d.spotlight!.filePath, '/b.sfc');
  });

  test('mastered games are excluded from continue and mastery buckets', () {
    final d = buildHomeDashboard([
      _game('/done.sfc', total: 5, earned: 5),
      _game('/wip.sfc', total: 5, earned: 3),
    ]);
    final paths = [
      ...d.continuePlaying.map((r) => r.filePath),
      ...d.closestToMastery.map((r) => r.filePath),
    ];
    expect(paths, isNot(contains('/done.sfc')));
    expect(paths, contains('/wip.sfc'));
  });

  test('continue playing orders by recency, mastery orders by completion', () {
    final older = DateTime(2024, 1, 1);
    final newer = DateTime(2024, 6, 1);
    // A is further along but played longer ago; B is less complete but newer.
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 8, lastPlayed: older),
      _game('/b.sfc', total: 10, earned: 3, lastPlayed: newer),
    ]);
    expect(d.continuePlaying.first.filePath, '/b.sfc'); // recency
    expect(d.closestToMastery.first.filePath, '/a.sfc'); // completion
  });

  test('beat spotlight is the most-complete unbeaten game, not the mastery hero',
      () {
    final d = buildHomeDashboard([
      _game('/wip1.sfc', total: 10, earned: 9), // 90% -> mastery hero
      _game('/beaten.sfc', total: 10, earned: 7, award: RaAward.beatenHardcore),
      _game('/wip2.sfc', total: 10, earned: 5), // 50%, unbeaten -> beat hero
    ]);
    expect(d.spotlight!.filePath, '/wip1.sfc');
    // The 70% game is further along but already beaten, so it's skipped; the
    // 90% game is excluded because it's the mastery hero.
    expect(d.beatSpotlight!.filePath, '/wip2.sfc');
  });

  test('beat spotlight is null when every started game is already beaten', () {
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 6, award: RaAward.beatenHardcore),
      _game('/b.sfc', total: 10, earned: 3, award: RaAward.beatenSoftcore),
    ]);
    expect(d.beatSpotlight, isNull);
  });

  test('unplayed games fall to popular, biggest community first', () {
    final d = buildHomeDashboard([
      _game('/small.sfc', total: 10, earned: 0, players: 100),
      _game('/big.sfc', total: 10, earned: 0, players: 900),
    ]);
    expect(d.continuePlaying, isEmpty);
    expect(d.popularUnplayed.map((r) => r.filePath).toList(),
        ['/big.sfc', '/small.sfc']);
    // No in-progress games, so the hero falls back to the most-wanted unplayed.
    expect(d.spotlight!.filePath, '/big.sfc');
  });

  test('games without an achievement set are ignored', () {
    final d = buildHomeDashboard([
      _game('/nosets.sfc', total: 0, earned: 0),
    ]);
    expect(d.hasContent, isFalse);
    expect(d.stats.mastered, 0);
  });

  test('stats sum library totals across systems and earned achievements', () {
    final systems = [
      SystemSummary(
        systemPath: '/snes',
        systemId: '',
        name: 'SNES',
        consoleId: 3,
        totalGames: 40,
        gamesScanned: 40,
        gamesWithAchievements: 12,
        totalSizeBytes: 1000,
        lastScanned: null,
      ),
    ];
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 10), // mastered, 10 earned
      _game('/b.sfc', total: 10, earned: 4), // 4 earned
    ], systems: systems);
    expect(d.stats.totalGames, 40);
    expect(d.stats.systems, 1);
    expect(d.stats.mastered, 1);
    expect(d.stats.achievementsEarned, 14);
    expect(d.stats.totalSizeBytes, 1000);
  });
}
