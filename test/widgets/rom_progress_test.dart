import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/rom_progress.dart';

RomResult _rom({int? earned, int? total, RaAward? award}) {
  final r = RomResult(filePath: '/x', fileName: 'x');
  r.earnedAchievements = earned;
  r.achievementCount = total;
  r.highestAward = award;
  return r;
}

Future<Color?> _labelColor(WidgetTester tester, RomResult rom, String label) async {
  await tester.pumpWidget(MaterialApp(
    theme: uiTheme(UiTokens.light),
    home: Scaffold(body: RomProgress(rom: rom)),
  ));
  return tester.widget<Text>(find.text(label)).style?.color;
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

    test('completed award at 100% says completed, not mastered', () {
      final hint = RomProgress.masteryHint(
          _rom(earned: 10, total: 10, award: RaAward.completed));
      expect(hint, contains('completed'));
      expect(hint, isNot(contains('mastered')));
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

  group('RomProgress label', () {
    testWidgets('shows the count when no award', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: Scaffold(body: RomProgress(rom: _rom(earned: 12, total: 40))),
      ));
      expect(find.text('12 / 40'), findsOneWidget);
    });

    testWidgets('award overrides the count: partial progress still reads Beaten',
        (tester) async {
      final rom = _rom(earned: 12, total: 40, award: RaAward.beatenHardcore);
      await tester.pumpWidget(MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: Scaffold(body: RomProgress(rom: rom)),
      ));
      expect(find.text('Beaten'), findsOneWidget);
      expect(find.text('12 / 40'), findsNothing);
    });

    testWidgets('completed and mastered are distinct labels at 100%',
        (tester) async {
      expect(
        await _labelColor(
            tester, _rom(earned: 40, total: 40, award: RaAward.completed),
            'Completed ✓'),
        UiTokens.light.warning,
      );
      expect(find.text('Mastered ★'), findsNothing);

      await _labelColor(
          tester, _rom(earned: 40, total: 40, award: RaAward.mastered),
          'Mastered ★');
      expect(find.text('Completed ✓'), findsNothing);
    });

    testWidgets('beaten uses the games-highlight token', (tester) async {
      final color = await _labelColor(
        tester,
        _rom(earned: 5, total: 20, award: RaAward.beatenSoftcore),
        'Beaten',
      );
      expect(color, UiTokens.light.accentGames);
    });
  });
}
