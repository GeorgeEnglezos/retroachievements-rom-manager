import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/least_played_score.dart';

void main() {
  final now = DateTime(2026, 7, 13);
  double? score(int players, DateTime? created) =>
      leastPlayedScore(players: players, setCreated: created, now: now);

  test('null setCreated → null (unrankable)', () {
    expect(score(500, null), isNull);
  });

  test('younger than grace period → null', () {
    // 1 month old, inside the 6-month grace window.
    expect(score(300, now.subtract(const Duration(days: 30))), isNull);
  });

  test('old + few players ranks below new + same players (log-dampened)', () {
    final old = score(500, DateTime(2023, 1, 1))!; // ~3.5y old
    final fresh = score(500, now.subtract(const Duration(days: 210)))!;
    // Same players, but the older set is judged more deletable → lower score.
    expect(old, lessThan(fresh));
  });

  test('log-dampened: fewer players → lower score at equal age', () {
    final quiet = score(200, DateTime(2024, 1, 1))!;
    final popular = score(5000, DateTime(2024, 1, 1))!;
    expect(quiet, lessThan(popular));
  });
}
