import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/scraper/scraped_store.dart';
import 'package:rarm/widgets/ra_image.dart';
import 'package:rarm/widgets/rom_grid_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onOpen fires on tap and preempts the single-ROM dialog',
      (tester) async {
    var opened = false;
    final rom = RomResult(
        filePath: 'psx/FF7 (Disc 1).chd', fileName: 'FF7 (Disc 1).chd')
      ..status = RomStatus.supported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RomGridItem(
          rom: rom,
          store: PlaylistStore(),
          onOpen: () => opened = true,
          discCount: 2,
        ),
      ),
    ));

    expect(find.text('💿 2'), findsOneWidget); // disc badge
    await tester.tap(find.byType(RomGridItem));
    await tester.pump();
    expect(opened, true);
    // No single-ROM dialog opened (onOpen took precedence).
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('local-only rom is tappable and opens the detail dialog',
      (tester) async {
    final rom = RomResult(filePath: 'ps3/game.iso', fileName: 'game.iso')
      ..status = RomStatus.localOnly
      ..consoleId = -3
      ..consoleName = 'PlayStation 3'
      ..fileSize = 1024;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())),
    ));

    // No "Not fetched" label; shows the filename.
    expect(find.text('Not fetched'), findsNothing);
    expect(find.text('game.iso'), findsOneWidget);

    await tester.tap(find.byType(RomGridItem));
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('unmatched rom with imported metadata opens the detail dialog',
      (tester) async {
    ScrapedStore.instance.seed(
        const ScrapedGame(romPath: 'snes/imported.sfc', title: 'Imported'));
    final rom = RomResult(filePath: 'snes/imported.sfc', fileName: 'imported.sfc')
      ..status = RomStatus.unsupported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())),
    ));

    await tester.tap(find.byType(RomGridItem));
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('unmatched rom without imported metadata stays inert',
      (tester) async {
    final rom = RomResult(filePath: 'snes/mystery.sfc', fileName: 'mystery.sfc')
      ..status = RomStatus.unsupported;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())),
    ));

    await tester.tap(find.byType(RomGridItem));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('localOnly rom falls back to the scraped box art thumbnail',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('grid_thumb');
    addTearDown(() => dir.deleteSync(recursive: true));
    final art = File(p.join(dir.path, 'game.png'))..writeAsBytesSync(kTinyPng);
    ScrapedStore.instance.seed(ScrapedGame(
      romPath: 'ps3/scraped.iso',
      title: 'Scraped',
      images: {'boxart': art.path},
    ));

    final rom = RomResult(filePath: 'ps3/scraped.iso', fileName: 'scraped.iso')
      ..status = RomStatus.localOnly;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())),
    ));

    // cacheWidth wraps the FileImage in a ResizeImage.
    final provider =
        (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
            .imageProvider;
    expect((provider as FileImage).file.path, art.path);
  });

  testWidgets('metadataOnly rom renders its third-party cover', (tester) async {
    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..gameTitle = 'Racer'
      ..imageUrl = 'https://cdn.screenscraper.fr/box.png';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())),
    ));
    // The absolute cover URL is used as-is (not prefixed with the RA host).
    final img = tester.widget<RaImage>(find.byType(RaImage));
    expect(img.url, 'https://cdn.screenscraper.fr/box.png');
  });
}
