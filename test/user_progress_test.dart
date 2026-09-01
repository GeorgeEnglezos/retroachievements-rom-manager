import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/user_progress.dart';
import 'package:rarm/services/ra_service.dart';

void main() {
  group('UserProgress JSON round-trip', () {
    test('preserves the award and its date on disk', () {
      final p = UserProgress(
        gameId: 7,
        earnedAchievements: 12,
        earnedHardcore: 5,
        lastPlayed: DateTime.parse('2026-05-01 10:00:00'),
        highestAward: RaAward.beatenHardcore,
        highestAwardDate: DateTime.parse('2026-06-01 08:00:00'),
      );
      final back = UserProgress.fromJson(p.toJson());
      expect(back.highestAward, RaAward.beatenHardcore);
      expect(back.highestAwardDate, DateTime.parse('2026-06-01 08:00:00'));
    });

    test('legacy record without award reads as none, not a crash', () {
      final back = UserProgress.fromJson({
        'gameId': 1,
        'earnedAchievements': 3,
        'earnedHardcore': 0,
      });
      expect(back.highestAward, RaAward.none);
      expect(back.highestAwardDate, isNull);
    });

    test('an unknown persisted award name degrades to none', () {
      final back = UserProgress.fromJson({
        'gameId': 1,
        'earnedAchievements': 0,
        'earnedHardcore': 0,
        'highestAward': 'a-tier-added-later',
      });
      expect(back.highestAward, RaAward.none);
    });
  });
}
