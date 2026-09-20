import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/widgets/game_detail_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

RomResult _disc(String name) =>
    RomResult(filePath: 'psx/$name', fileName: name)
      ..status = RomStatus.notFetched;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('achievementTypeLabel', () {
    test('the marked RA types are labelled', () {
      // These exact strings are RA's `Type` values; the highlight keys off them.
      expect(achievementTypeLabel('win_condition'), 'Win condition');
      expect(achievementTypeLabel('progression'), 'Progression');
      expect(achievementTypeLabel('missable'), 'Missable');
      // Standard and legacy-null achievements get no marker.
      expect(achievementTypeLabel(null), isNull);
      expect(achievementTypeLabel(''), isNull);
    });
  });

  testWidgets('multi-disc dialog switches the selected disc', (tester) async {
    final discs = [_disc('FF7 (Disc 1).chd'), _disc('FF7 (Disc 2).chd')];
    await tester.pumpWidget(MaterialApp(
      home: GameDetailDialog(rom: discs.first, discs: discs),
    ));
    await tester.pump();

    expect(find.text('File 1 of 2'), findsOneWidget);
    expect(find.text('Disc 1'), findsOneWidget);
    expect(find.text('Disc 2'), findsOneWidget);

    await tester.tap(find.text('Disc 2'));
    await tester.pump();
    expect(find.text('File 2 of 2'), findsOneWidget);
  });

  testWidgets('single-ROM dialog shows no disc switcher', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GameDetailDialog(rom: _disc('Solo (USA).chd')),
    ));
    await tester.pump();
    expect(find.textContaining('File '), findsNothing);
  });

  testWidgets('local-only dialog shows local info but no RA sections',
      (tester) async {
    final rom = RomResult(filePath: 'ps3/game.iso', fileName: 'game.iso')
      ..status = RomStatus.localOnly
      ..consoleId = -3
      ..consoleName = 'PlayStation 3';
    await tester.pumpWidget(MaterialApp(
      home: GameDetailDialog(rom: rom),
    ));
    await tester.pump();

    // Local info kept.
    expect(find.text('game.iso'), findsOneWidget);
    expect(find.text('PlayStation 3'), findsOneWidget);
    // RA-only sections hidden (no achievement/player stats).
    expect(find.text('Achievements'), findsNothing);
    expect(find.text('Players'), findsNothing);
  });

  testWidgets('metadataOnly dialog shows meta rows but no achievement stats',
      (tester) async {
    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Some Racer'
      ..consoleName = 'PlayStation 3'
      ..publisher = 'Acme';
    await tester.pumpWidget(MaterialApp(home: GameDetailDialog(rom: rom)));
    await tester.pump();

    expect(find.text('Publisher'), findsOneWidget); // meta row shown
    expect(find.text('Achievements'), findsNothing); // achievement UI hidden
    expect(find.text('Players'), findsNothing);
  });

  testWidgets('scraped values fill RA gaps in the meta rows', (tester) async {
    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Some Racer'
      ..publisher = ''; // empty RA field must fall through to scraped
    const scraped = ScrapedGame(
      romPath: 'ps3/racer.iso',
      title: 'Some Racer',
      publisher: 'Scraped Pub',
      genre: 'Racing',
      players: '1-2',
      rating: '0.85',
    );
    await tester.pumpWidget(
        MaterialApp(home: GameDetailDialog(rom: rom, scraped: scraped)));
    await tester.pump();

    expect(find.text('Scraped Pub'), findsOneWidget); // gap-filled publisher
    expect(find.text('Racing'), findsOneWidget); // gap-filled genre
    expect(find.text('1-2'), findsOneWidget); // players row rendered
    expect(find.text('0.85'), findsOneWidget); // rating row rendered
  });

  testWidgets('tapping an imported image opens the fullscreen viewer',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('dialog_zoom');
    addTearDown(() => dir.deleteSync(recursive: true));
    final art = File(p.join(dir.path, 'shot.png'))..writeAsBytesSync(kTinyPng);

    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Some Racer';
    await tester.pumpWidget(MaterialApp(
      home: GameDetailDialog(
        rom: rom,
        scraped: ScrapedGame(
          romPath: 'ps3/racer.iso',
          title: 'Some Racer',
          images: {'screenshot': art.path},
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byType(Image).first);
    await tester.pump(); // start the dialog route
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('low-confidence match shows an unverified indicator',
      (tester) async {
    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Some Racer'
      ..lowConfidenceMatch = true;
    await tester.pumpWidget(MaterialApp(home: GameDetailDialog(rom: rom)));
    await tester.pump();
    expect(find.text('Unverified name match'), findsOneWidget);
  });

  testWidgets('wide window splits the dialog into two panels', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rom = RomResult(filePath: 'psx/ff7.chd', fileName: 'ff7.chd')
      ..status = RomStatus.supported
      ..gameId = 123
      ..gameTitle = 'Final Fantasy VII';
    await tester.pumpWidget(MaterialApp(home: GameDetailDialog(rom: rom)));
    await tester.pump();

    expect(find.byKey(const Key('gameDetailPanel')), findsOneWidget);
    expect(find.byKey(const Key('gameAchievementsPanel')), findsOneWidget);
  });

  testWidgets('narrow window keeps the dialog in one column', (tester) async {
    final rom = RomResult(filePath: 'psx/ff7.chd', fileName: 'ff7.chd')
      ..status = RomStatus.supported
      ..gameId = 123
      ..gameTitle = 'Final Fantasy VII';
    await tester.pumpWidget(MaterialApp(home: GameDetailDialog(rom: rom)));
    await tester.pump();

    expect(find.byKey(const Key('gameAchievementsPanel')), findsNothing);
  });

  testWidgets('wide window keeps one column when there are no achievements',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Some Racer';
    await tester.pumpWidget(MaterialApp(home: GameDetailDialog(rom: rom)));
    await tester.pump();

    expect(find.byKey(const Key('gameAchievementsPanel')), findsNothing);
  });
}
