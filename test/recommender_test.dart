import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/recommender.dart';

RecGame g(String title,
        {required int total,
        required int earned,
        int hardcoreEarned = 0,
        int players = 0}) =>
    RecGame(
      title: title,
      systemName: 'NES',
      filePath: '/$title',
      total: total,
      earned: earned,
      hardcoreEarned: hardcoreEarned,
      players: players,
    );

void main() {
  test('closestToMastery ranks started-but-unfinished by completion', () {
    final r = Recommender.build([
      g('almost', total: 10, earned: 9),
      g('half', total: 10, earned: 5),
      g('mastered', total: 10, earned: 10), // excluded
      g('unplayed', total: 10, earned: 0), // excluded
    ]);
    expect(r.closestToMastery.map((e) => e.title), ['almost', 'half']);
  });

  test('popularUnplayed ranks unplayed by community size', () {
    final r = Recommender.build([
      g('niche', total: 10, earned: 0, players: 100),
      g('hit', total: 10, earned: 0, players: 9000),
    ]);
    expect(r.popularUnplayed.first.title, 'hit');
  });

  test('hardcoreReclears: casual-mastered, not hardcore, closest HC first', () {
    final r = Recommender.build([
      g('a', total: 10, earned: 10, hardcoreEarned: 8), // casual done, HC 80%
      g('b', total: 10, earned: 10, hardcoreEarned: 2), // casual done, HC 20%
      g('c', total: 10, earned: 10, hardcoreEarned: 10), // HC mastered, excluded
      g('d', total: 10, earned: 5, hardcoreEarned: 0), // not casual-mastered
    ]);
    expect(r.hardcoreReclears.map((e) => e.title), ['a', 'b']);
  });

  test('games without an achievement set are ignored', () {
    final r = Recommender.build([g('noset', total: 0, earned: 0)]);
    expect(r.isEmpty, isTrue);
  });

  test('limit caps each bucket', () {
    final games =
        List.generate(15, (i) => g('u$i', total: 10, earned: 0, players: i));
    final r = Recommender.build(games, limit: 5);
    expect(r.popularUnplayed.length, 5);
  });
}
