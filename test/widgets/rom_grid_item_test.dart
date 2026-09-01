import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/play_view.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/scraper/scraped_store.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/game_cover.dart';
import 'package:rarm/widgets/ra_image.dart';
import 'package:rarm/widgets/rom_grid_item.dart';
import 'package:rarm/widgets/ui/ui_progress_bar.dart';
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

  group('play-mode listing settings', () {
    tearDown(() {
      appModeListenable.value = AppMode.cleaning;
      playViewListenable.value = const PlayView();
    });

    RomResult named() =>
        RomResult(filePath: 'snes/smw.sfc', fileName: 'smw.sfc')
          ..status = RomStatus.supported
          ..gameTitle = 'Super Mario World'
          ..fileSize = 512 * 1024;

    Widget host(RomResult rom) => MaterialApp(
        home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())));

    testWidgets('cleaning shows the file name and size', (tester) async {
      await tester.pumpWidget(host(named()));
      expect(find.text('Super Mario World'), findsOneWidget);
      expect(find.text('smw.sfc'), findsOneWidget);
      expect(find.text('512.0 KB'), findsOneWidget);
    });

    testWidgets('play mode drops them by default', (tester) async {
      appModeListenable.value = AppMode.gaming;
      await tester.pumpWidget(host(named()));
      expect(find.text('Super Mario World'), findsOneWidget);
      expect(find.text('smw.sfc'), findsNothing);
      expect(find.text('512.0 KB'), findsNothing);
    });

    testWidgets('play mode can title cards by file name', (tester) async {
      appModeListenable.value = AppMode.gaming;
      playViewListenable.value = const PlayView(raTitle: false);
      await tester.pumpWidget(host(named()));
      expect(find.text('Super Mario World'), findsNothing);
      expect(find.text('smw.sfc'), findsOneWidget);
    });
  });

  group('home-style meta', () {
    RomResult inProgress() =>
        RomResult(filePath: 'snes/ct.sfc', fileName: 'Chrono Trigger.sfc')
          ..status = RomStatus.supported
          ..gameTitle = 'Chrono Trigger'
          ..consoleName = 'SNES'
          ..achievementCount = 120
          ..earnedAchievements = 44;

    Widget host(RomResult rom) => MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: Scaffold(body: RomGridItem(rom: rom, store: PlaylistStore())));

    testWidgets('renders through the shared GameCover', (tester) async {
      await tester.pumpWidget(host(inProgress()));
      expect(find.byType(GameCover), findsOneWidget);
    });

    testWidgets('shows earned/total numbers, not a text-area progress bar',
        (tester) async {
      await tester.pumpWidget(host(inProgress()));
      // The Home-style read: numbers, and the console name is gone (we are
      // already inside a console folder).
      expect(find.text('44/120'), findsOneWidget);
      expect(find.textContaining('SNES'), findsNothing);
      // Progress lives on the art (a strip), never as a bar in the text block.
      expect(find.byType(UiProgressBar), findsNothing);
    });

    testWidgets('a mastered set shows the trophy, not a strip', (tester) async {
      final rom = inProgress()..earnedAchievements = 120;
      await tester.pumpWidget(host(rom));
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('chips ride the numbers row (hot flag inline)', (tester) async {
      final rom = inProgress()
        ..numPlayersCasual = 100000; // over the hot threshold
      await tester.pumpWidget(host(rom));
      // The chip and the numbers share one GameMetaRow.
      final row = find.ancestor(
          of: find.text('🔥 HOT'), matching: find.byType(GameMetaRow));
      expect(row, findsOneWidget);
      expect(
          find.descendant(of: row, matching: find.text('44/120')),
          findsOneWidget);
    });
  });

  group('cell fit', () {
    // Worst case for the text block: every optional line present, a long title,
    // and a file name carrying every tag chip the parser can produce.
    RomResult loaded() => RomResult(
          filePath: 'snes/long.sfc',
          fileName: 'The Legend of Something Very Long Indeed (Europe) '
              '(En,Fr,De,Es,It,Pt,Nl,Sv) [Hack] [!].sfc',
        )
          ..status = RomStatus.supported
          ..gameTitle = 'The Legend of Something Very Long Indeed'
          ..achievementCount = 120
          ..earnedAchievements = 44
          ..numPlayersCasual = 99999
          ..duplicateGroupId = 1
          ..fileSize = 512 * 1024;

    // The grid delegate (maxCrossAxisExtent 300, childAspectRatio 0.75) hands
    // a phone-width viewport two columns of roughly 155x207 — the smallest cell
    // the app can produce, and the one a multi-run chip strip used to burst.
    for (final cell in const [Size(155, 207), Size(300, 400)]) {
      testWidgets(
          'a fully loaded tile fits a ${cell.width.toInt()}x${cell.height.toInt()} cell',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: uiTheme(UiTokens.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: cell.width,
                height: cell.height,
                child: RomGridItem(rom: loaded(), store: PlaylistStore()),
              ),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
