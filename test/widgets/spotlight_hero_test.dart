import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/spotlight_hero.dart';
import 'package:rarm/widgets/ui/ui_progress_bar.dart';

// boxArt null → the hero uses its gradient background (no network image).
RomResult _g(String title, {int total = 10, int earned = 7}) =>
    RomResult(filePath: '/a.sfc', fileName: '$title.sfc')
      ..status = RomStatus.supported
      ..gameTitle = title
      ..consoleName = 'SNES'
      ..achievementCount = total
      ..earnedAchievements = earned;

void main() {
  testWidgets('shows the title and completion read, and the banner fires onOpen',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightHero(rom: _g('Chrono Trigger'), onOpen: () => opened = true),
      ),
    ));

    expect(find.text('Chrono Trigger'), findsOneWidget);
    // Console and the achievement read share one meta line; genre and size
    // are hidden, and completion is carried by the bar rather than a label.
    expect(find.text('SNES  ·  7/10 achievements'), findsOneWidget);

    // The completion read is a bar that sweeps its fill in on mount, not a
    // static block or a percent label.
    expect(find.byType(UiProgressBar), findsOneWidget);
    final bar = tester.widget<UiProgressBar>(find.byType(UiProgressBar));
    expect(bar.value, closeTo(0.7, 0.001));

    await tester.tap(find.byType(SpotlightHero));
    expect(opened, isTrue);
  });

  testWidgets('defaults to the mastery eyebrow, and takes a custom one',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SpotlightHero(rom: _g('Default'), onOpen: () {})),
    ));
    expect(find.text('CLOSEST TO MASTERY'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightHero(
            rom: _g('Custom'), eyebrow: 'CLOSEST TO BEAT', onOpen: () {}),
      ),
    ));
    expect(find.text('CLOSEST TO BEAT'), findsOneWidget);
    expect(find.text('CLOSEST TO MASTERY'), findsNothing);
  });

  testWidgets('a set with no achievements shows no bar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightHero(
            rom: _g('Unknown', total: 0, earned: 0), onOpen: () {}),
      ),
    ));
    expect(find.byType(UiProgressBar), findsNothing);
  });

  testWidgets('a fully earned set reads all of its achievements', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpotlightHero(
            rom: _g('Super Metroid', total: 10, earned: 10), onOpen: () {}),
      ),
    ));
    expect(find.text('SNES  ·  10/10 achievements'), findsOneWidget);
  });

  testWidgets('compact is shorter than the desktop hero at phone width',
      (tester) async {
    Future<double> heightOf(bool compact) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 358,
            child: SpotlightHero(
                rom: _g('The Legend of Zelda: A Link to the Past'),
                compact: compact,
                onOpen: () {}),
          ),
        ),
      ));
      return tester.getSize(find.byType(SpotlightHero)).height;
    }

    final compact = await heightOf(true);
    final full = await heightOf(false);
    expect(compact, lessThan(full));
  });
}
