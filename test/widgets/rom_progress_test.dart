import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/rom_progress.dart';

RomResult _rom({int? earned, int? total}) {
  final r = RomResult(filePath: '/x', fileName: 'x');
  r.earnedAchievements = earned;
  r.achievementCount = total;
  return r;
}

void main() {
  group('RomProgress.masteryHint', () {
    test('null without progress data', () {
      expect(RomProgress.masteryHint(_rom(total: 10)), isNull);
      expect(RomProgress.masteryHint(_rom(earned: 0, total: 0)), isNull);
    });

    test('null when not started', () {
      expect(RomProgress.masteryHint(_rom(earned: 0, total: 10)), isNull);
    });

    test('mastered message at 100%', () {
      expect(RomProgress.masteryHint(_rom(earned: 10, total: 10)),
          contains('mastered'));
    });

    test('close-to-mastery flag at >=80%', () {
      final hint = RomProgress.masteryHint(_rom(earned: 9, total: 10));
      expect(hint, contains('Close to mastery'));
      expect(hint, contains('1 achievement to go')); // singular
    });

    test('plain remaining count below 80%', () {
      final hint = RomProgress.masteryHint(_rom(earned: 5, total: 10));
      expect(hint, '5 achievements to go');
    });
  });
}
