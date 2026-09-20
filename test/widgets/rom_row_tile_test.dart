import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/rom_row.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/play_view.dart';
import 'package:rarm/services/member_key.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/rom_tap.dart';
import 'package:rarm/services/scraper/scraped_store.dart';
import 'package:rarm/services/storage_treemap.dart' show TreemapItem;
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/game_detail_dialog.dart';
import 'package:rarm/widgets/rom_row_tile.dart';
import 'package:rarm/widgets/row_display.dart';
import 'package:rarm/widgets/ui/ui_progress_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: ListView(children: [child])),
      );

  Widget hostRow(RomRow row,
          {RowDisplay display = RowDisplay.roms, VoidCallback? onFetch}) =>
      host(RomRowTile(
          row: row,
          display: display,
          store: PlaylistStore(),
          onFetch: onFetch));

  Widget hostRom(RomResult rom) => hostRow(RomRow.fromRom(rom));

  RomResult rom(String name, {RomStatus status = RomStatus.supported}) =>
      RomResult(filePath: 'C:\\roms\\snes\\$name', fileName: name)
        ..status = status;

  group('content', () {
    testWidgets('storage folder row shows title + chevron, no progress',
        (tester) async {
      final row = RomRow.fromTreemap(
          TreemapItem('GBA', 5000, path: r'C:\ROMs\GBA'),
          fraction: 1.0,
          isFolder: true);
      await tester.pumpWidget(hostRow(row, display: RowDisplay.storage));
      expect(find.text('GBA'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('shows the cleanup score label when present', (tester) async {
      await tester
          .pumpWidget(hostRow(const RomRow(title: 'Block Stacker', scoreLabel: '128')));
      expect(find.text('128'), findsOneWidget);
    });

    testWidgets('local-only row shows filename + size, no "Not fetched"',
        (tester) async {
      final r = RomResult(filePath: 'ps3/game.iso', fileName: 'game.iso')
        ..status = RomStatus.localOnly
        ..consoleId = -3
        ..fileSize = 1024;
      await tester.pumpWidget(hostRom(r));
      await tester.pump();

      expect(find.text('game.iso'), findsOneWidget);
      expect(find.text('Not fetched'), findsNothing);
      expect(find.text('1.0 KB'), findsOneWidget);
    });

    testWidgets('local-only row is tappable and opens the detail dialog',
        (tester) async {
      final r = RomResult(filePath: 'ps3/game.iso', fileName: 'game.iso')
        ..status = RomStatus.localOnly
        ..consoleId = -3
        ..consoleName = 'PlayStation 3';
      await tester.pumpWidget(hostRom(r));
      await tester.pump();

      await tester.tap(find.byType(RomRowTile));
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('unmatched row with imported metadata opens the detail dialog',
        (tester) async {
      ScrapedStore.instance.seed(
          const ScrapedGame(romPath: 'snes/imported.sfc', title: 'Imported'));
      final r = RomResult(filePath: 'snes/imported.sfc', fileName: 'imported.sfc')
        ..status = RomStatus.unsupported;
      await tester.pumpWidget(hostRom(r));
      await tester.pump();

      await tester.tap(find.byType(RomRowTile));
      await tester.pump();
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('unmatched row without imported metadata stays inert',
        (tester) async {
      await tester.pumpWidget(
          hostRom(rom('Mystery.sfc', status: RomStatus.unsupported)));
      await tester.pump();

      await tester.tap(find.byType(RomRowTile));
      await tester.pump();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('play tap action launches instead of opening the details',
        (tester) async {
      romTapListenable.value = RomTapAction.play;
      addTearDown(() => romTapListenable.value = RomTapAction.detail);
      final r = rom('Block Stacker.sfc')..consoleId = 3;
      await tester.pumpWidget(hostRom(r));
      await tester.pump();

      await tester.tap(find.byType(RomRowTile));
      await tester.pumpAndSettle();
      // No emulator is set in this profile, so the launch stops at the
      // set-emulator prompt: proof the tap went to Play, not to the details.
      expect(find.textContaining('Set emulator for'), findsOneWidget);
      expect(find.byType(GameDetailDialog), findsNothing);
    });

    testWidgets('play tap action beats a screen-supplied onTap',
        (tester) async {
      romTapListenable.value = RomTapAction.play;
      addTearDown(() => romTapListenable.value = RomTapAction.detail);
      var opened = false;
      final r = rom('Block Stacker.sfc')..consoleId = 3;
      await tester.pumpWidget(hostRow(
          RomRow.fromRom(r, onTap: () => opened = true)));
      await tester.pump();

      await tester.tap(find.byType(RomRowTile));
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(find.textContaining('Set emulator for'), findsOneWidget);
    });

    testWidgets('chip strip wraps instead of overflowing on a narrow row',
        (tester) async {
      // Many chips (region + several language tags + a hack tag) on a narrow
      // mobile-width row used to overflow the subtitle Row.
      final r = RomResult(
        filePath: 'snes/game.zip',
        fileName: 'Game (Europe) (En,Fr,De,Es,It,Pt) [Hack].zip',
      )
        ..status = RomStatus.supported
        ..achievementCount = 120;

      // List width where the chips exceed the subtitle Row; unbounded height
      // (scroll view) so the chips wrap vertically instead of the test hitting
      // an unrelated viewport-height overflow.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: RomRowTile(
                row: RomRow.fromRom(r),
                display: const RowDisplay(),
                store: PlaylistStore(),
              ),
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('scraped box art', () {
    /// Seeds the scraped store with a real on-disk image for [romPath] and
    /// returns its path.
    String seedArt(String romPath, String tmpPrefix) {
      final dir = Directory.systemTemp.createTempSync(tmpPrefix);
      addTearDown(() => dir.deleteSync(recursive: true));
      final art = File(p.join(dir.path, 'game.png'))..writeAsBytesSync(kTinyPng);
      ScrapedStore.instance.seed(ScrapedGame(
        romPath: romPath,
        title: 'Tile',
        images: {'boxart': art.path},
      ));
      return art.path;
    }

    testWidgets('localOnly row falls back to the scraped box art thumbnail',
        (tester) async {
      final artPath = seedArt('ps3/tile.iso', 'tile_thumb');
      final r = RomResult(filePath: 'ps3/tile.iso', fileName: 'tile.iso')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(host(RomRowTile(
        row: RomRow.fromRom(r),
        display: const RowDisplay(),
        store: PlaylistStore(),
      )));

      // cacheWidth wraps the FileImage in a ResizeImage.
      final provider =
          (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
              .imageProvider;
      expect((provider as FileImage).file.path, artPath);
    });

    testWidgets('showBoxArt off suppresses the scraped thumbnail',
        (tester) async {
      seedArt('ps3/noart.iso', 'tile_thumb_off');
      final r = RomResult(filePath: 'ps3/noart.iso', fileName: 'noart.iso')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(host(RomRowTile(
        row: RomRow.fromRom(r),
        display: const RowDisplay(showBoxArt: false),
        store: PlaylistStore(),
      )));

      expect(find.byType(Image), findsNothing);
    });
  });

  group('context menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byType(RomRowTile), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
    }

    testWidgets('right-click opens menu with file actions', (tester) async {
      await tester.pumpWidget(hostRom(rom('Blahblah.sfc')..gameId = 42));
      await openMenu(tester);

      expect(find.text('Reveal in Explorer'), findsOneWidget);
      expect(find.text('Copy path'), findsOneWidget);
      expect(find.text('Search Google'), findsOneWidget);
      expect(find.text('Open RA page'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('unmatched game hides Open RA page', (tester) async {
      await tester
          .pumpWidget(hostRom(rom('Mystery.sfc', status: RomStatus.unsupported)));
      await openMenu(tester);

      expect(find.text('Reveal in Explorer'), findsOneWidget);
      expect(find.text('Open RA page'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('local-only game omits Fetch and Open RA page', (tester) async {
      final r = RomResult(filePath: r'C:\roms\ps3\game.iso', fileName: 'game.iso')
        ..status = RomStatus.localOnly
        ..consoleId = -3;
      // onFetch wired, but must stay hidden for local-only.
      await tester
          .pumpWidget(hostRow(RomRow.fromRom(r), onFetch: () {}));
      await openMenu(tester);

      expect(find.text('Fetch'), findsNothing);
      expect(find.text('Open RA page'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('multi-disc delete prompts for all discs', (tester) async {
      final r = rom('Blahblah.sfc')..gameId = 42;
      await tester.pumpWidget(hostRow(RomRow(
        title: 'Blahblah',
        filePath: r.filePath,
        rom: r,
        discCount: 3,
        groupPaths: [
          r.filePath,
          r'C:\roms\snes\Blahblah (Disc 2).sfc',
          r'C:\roms\snes\Blahblah (Disc 3).sfc',
        ],
      )));
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('all 3 discs'), findsOneWidget);
    });
  });

  group('play-mode listing settings', () {
    tearDown(() {
      appModeListenable.value = AppMode.cleaning;
      playViewListenable.value = const PlayView();
    });

    RomResult named() =>
        RomResult(filePath: r'C:\roms\snes\smw.sfc', fileName: 'smw.sfc')
          ..status = RomStatus.supported
          ..gameTitle = 'Super Mario World'
          ..fileSize = 512 * 1024;

    testWidgets('cleaning shows the file name and size lines', (tester) async {
      await tester.pumpWidget(hostRom(named()));
      expect(find.text('Super Mario World'), findsOneWidget);
      expect(find.text('smw.sfc'), findsOneWidget);
      expect(find.text('512.0 KB'), findsOneWidget);
    });

    testWidgets('play mode drops the file name and size by default',
        (tester) async {
      appModeListenable.value = AppMode.gaming;
      await tester.pumpWidget(hostRom(named()));
      expect(find.text('Super Mario World'), findsOneWidget);
      expect(find.text('smw.sfc'), findsNothing);
      expect(find.text('512.0 KB'), findsNothing);
    });

    testWidgets('play mode can title rows by file name instead',
        (tester) async {
      appModeListenable.value = AppMode.gaming;
      playViewListenable.value = const PlayView(raTitle: false);
      await tester.pumpWidget(hostRom(named()));
      expect(find.text('Super Mario World'), findsNothing);
      expect(find.text('smw.sfc'), findsOneWidget);
    });
  });

  group('progress bar colour', () {
    RomResult inProgress(String path) =>
        RomResult(filePath: path, fileName: 'ff.sfc')
          ..status = RomStatus.supported
          ..achievementCount = 10
          ..earnedAchievements = 4;

    UiProgressBar barOf(WidgetTester tester) =>
        tester.widget<UiProgressBar>(find.byType(UiProgressBar));

    testWidgets('a normal row keeps its award colour', (tester) async {
      PlaylistStore().resetForTest();
      await tester.pumpWidget(hostRom(inProgress('C:\\roms\\snes\\plain.sfc')));
      await tester.pump();
      // In-progress, no award -> the supported hue, not the favorite ink.
      expect(barOf(tester).color, UiTokens.standard.supported);
    });

    testWidgets('a favorite row flips the bar to favoriteInk', (tester) async {
      final store = PlaylistStore()..resetForTest();
      final r = inProgress('C:\\roms\\snes\\fav.sfc');
      await store.toggleMember(
          favoritesId, memberKeyFor(gameId: r.gameId, filePath: r.filePath));
      await tester.pumpWidget(hostRom(r));
      await tester.pump();
      expect(barOf(tester).color, UiTokens.standard.favoriteInk);
    });
  });

  group('progress bar on small screens', () {
    RomResult inProgress() => RomResult(filePath: 'C:\\r\\g.sfc', fileName: 'g.sfc')
      ..status = RomStatus.supported
      ..achievementCount = 10
      ..earnedAchievements = 4;

    testWidgets('a phone-sized screen drops the per-row bar', (tester) async {
      // shortestSide 400 < 600 -> no bar; the earned/total read stays.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hostRom(inProgress()));
      await tester.pump();
      expect(find.byType(UiProgressBar), findsNothing);
      expect(find.text('4/10'), findsOneWidget);
    });

    testWidgets('a larger screen keeps the bar', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(hostRom(inProgress()));
      await tester.pump();
      expect(find.byType(UiProgressBar), findsOneWidget);
    });
  });
}
