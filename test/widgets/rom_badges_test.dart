import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/hotness.dart';
import 'package:rarm/services/play_view.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/rom_badges.dart';
import 'package:rarm/widgets/rom_tag_badge.dart';

void main() {
  testWidgets('discBadge renders for 2+ discs, nothing below', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          final ui = context.ui;
          return Column(children: [
            discBadge(3, ui) ?? const Text('none-3'),
            discBadge(1, ui) ?? const Text('none-1'),
            discBadge(null, ui) ?? const Text('none-null'),
          ]);
        }),
      ),
    ));
    expect(find.text('💿 3'), findsOneWidget);
    expect(find.text('none-1'), findsOneWidget); // count < 2 → null
    expect(find.text('none-null'), findsOneWidget);
  });

  testWidgets('noAchBadge renders for unsupported/localOnly/metadataOnly',
      (tester) async {
    RomResult rom(RomStatus s) =>
        RomResult(filePath: 'a', fileName: 'a')..status = s;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          noAchBadge(rom(RomStatus.unsupported)) ?? const Text('none-1'),
          noAchBadge(rom(RomStatus.localOnly)) ?? const Text('none-2'),
          noAchBadge(rom(RomStatus.metadataOnly)) ?? const Text('none-3'),
          noAchBadge(rom(RomStatus.supported)) ?? const Text('none-supported'),
          noAchBadge(rom(RomStatus.notFetched)) ?? const Text('none-fetched'),
        ]),
      ),
    ));
    expect(find.text('NO ACH'), findsNWidgets(3));
    expect(find.text('none-supported'), findsOneWidget);
    expect(find.text('none-fetched'), findsOneWidget);
  });


  group('play-mode listing settings', () {
    setUp(() => playViewListenable.value = const PlayView());
    tearDown(() {
      appModeListenable.value = AppMode.cleaning;
      playViewListenable.value = const PlayView();
    });

    // HOT needs a supported set and NO ACH an unsupported one, so the harness
    // renders both and each assertion picks the badge it cares about.
    RomResult hot() =>
        RomResult(filePath: 'a', fileName: 'Game (E) [!].sfc')
          ..status = RomStatus.supported
          ..numPlayersCasual = hotPlayerThreshold
          ..achievementCount = 12
          ..duplicateGroupId = 1;
    RomResult unsupported() =>
        RomResult(filePath: 'b', fileName: 'Other (U).sfc')
          ..status = RomStatus.unsupported;

    Widget harness() => MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              final ui = context.ui;
              final h = hot();
              return Column(children: [
                hotBadge(h) ?? const Text('no-hot'),
                achBadge(h, ui) ?? const Text('no-ach-count'),
                noAchBadge(unsupported()) ?? const Text('no-noach'),
                dupBadge(h, ui) ?? const Text('no-dup'),
                ...tagBadges(h.fileName),
              ]);
            }),
          ),
        );

    testWidgets('cleaning mode shows every badge whatever is saved',
        (tester) async {
      // Cleaning must ignore the play settings entirely, so a listing being
      // audited never hides information.
      playViewListenable.value = const PlayView(
          hot: false, achievementCount: false, fileTags: false);
      await tester.pumpWidget(harness());
      expect(find.text('🔥 HOT'), findsOneWidget);
      expect(find.text('12 ACH'), findsOneWidget);
      expect(find.text('NO ACH'), findsOneWidget);
      expect(find.text('⧉ DUP'), findsOneWidget);
      expect(find.byType(RomTagBadge), findsWidgets);
    });

    testWidgets('play mode honours each toggle, and never shows DUP',
        (tester) async {
      appModeListenable.value = AppMode.gaming;
      playViewListenable.value = const PlayView(
          hot: false, achievementCount: false, fileTags: false);
      await tester.pumpWidget(harness());
      expect(find.text('no-hot'), findsOneWidget);
      expect(find.text('no-ach-count'), findsOneWidget);
      expect(find.text('no-noach'), findsOneWidget); // default: off
      expect(find.text('no-dup'), findsOneWidget); // never shown in play mode
      expect(find.byType(RomTagBadge), findsNothing);
    });

    testWidgets('play mode shows the badges left switched on', (tester) async {
      appModeListenable.value = AppMode.gaming;
      playViewListenable.value =
          const PlayView(noAchievements: true, fileTags: true);
      await tester.pumpWidget(harness());
      expect(find.text('🔥 HOT'), findsOneWidget);
      expect(find.text('12 ACH'), findsOneWidget);
      expect(find.text('NO ACH'), findsOneWidget);
      expect(find.text('no-dup'), findsOneWidget);
      expect(find.byType(RomTagBadge), findsWidgets);
    });
  });
}
