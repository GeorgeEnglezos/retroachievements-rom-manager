import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/rom_row.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/scraper/scraped_store.dart';
import 'package:rarm/services/storage_treemap.dart' show TreemapItem;
import 'package:rarm/widgets/rom_row_tile.dart';
import 'package:rarm/widgets/row_display.dart';
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

    testWidgets('chip strip wraps instead of overflowing on a narrow row',
        (tester) async {
      // Many chips (region + several language tags + a hack tag + ACH badge) on
      // a narrow mobile-width row used to overflow the subtitle Row.
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
}
