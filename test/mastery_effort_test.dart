import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/services/mastery_effort.dart';

Achievement _ach({required int trueRatio, required bool earned}) => Achievement(
      id: 1,
      title: 't',
      description: 'd',
      points: 5,
      trueRatio: trueRatio,
      badgeName: 'b',
      displayOrder: 0,
      numAwarded: 0,
      dateEarned: earned ? DateTime(2026) : null,
    );

void main() {
  test('sums TrueRatio of only the unearned achievements', () {
    final effort = masteryEffort([
      _ach(trueRatio: 10, earned: true), // earned → excluded
      _ach(trueRatio: 25, earned: false),
      _ach(trueRatio: 40, earned: false),
    ]);
    expect(effort, 65);
  });

  test('zero when fully earned or empty', () {
    expect(masteryEffort([_ach(trueRatio: 10, earned: true)]), 0);
    expect(masteryEffort(const []), 0);
  });
}
