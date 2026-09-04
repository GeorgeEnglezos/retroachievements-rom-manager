import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/recommender.dart';

RecGame g(String title,
        {required int total,
        required int earned,
        int hardcoreEarned = 0,
        int players = 0,
        int? gameId}) =>
    RecGame(
      title: title,
      systemName: 'NES',
      filePath: '/$title',
      gameId: gameId,
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

  test('the same game across two ROM libraries is recommended once', () {
    // Two separate library folders hold the same RA game (same gameId) as
    // different files; it must not appear twice.
    final r = Recommender.build([
      g('God of War (lib A)', total: 40, earned: 10, gameId: 2782),
      g('God of War (lib B)', total: 40, earned: 10, gameId: 2782),
    ]);
    expect(r.closestToMastery.length, 1);
  });

  test('duplicate copies collapse to the most-progressed one', () {
    final r = Recommender.build([
      g('copy A', total: 10, earned: 3, gameId: 99),
      g('copy B', total: 10, earned: 7, gameId: 99),
    ]);
    expect(r.closestToMastery.map((e) => e.earned), [7]);
  });

  test('limit caps each bucket', () {
    final games =
        List.generate(15, (i) => g('u$i', total: 10, earned: 0, players: i));
    final r = Recommender.build(games, limit: 5);
    expect(r.popularUnplayed.length, 5);
  });
}
