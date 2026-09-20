import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/cull_deck_builder.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/scraper/scraped_store.dart';
import 'package:rarm/widgets/cull_card.dart';
import 'package:rarm/widgets/game_detail_dialog.dart';
import 'package:rarm/widgets/ra_image.dart';
import 'package:rarm/widgets/rom_thumb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fixtures.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(height: 480, width: 320, child: child),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().clear();
    ScrapedStore.instance.clear();
  });

  group('art fallback', () {
    testWidgets('renders RA box art when present', (tester) async {
      final rom = RomResult(filePath: 'snes/alpha.sfc', fileName: 'alpha.sfc')
        ..status = RomStatus.supported
        ..gameId = 1
        ..imageBoxArt = '/Images/alpha_box.png';
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:1'),
        onSearch: () {},
      )));

      final img = tester.widget<RaImage>(find.byType(RaImage));
      expect(img.url, 'https://retroachievements.org/Images/alpha_box.png');
    });

    testWidgets('falls back to imported box art when RA has none',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('cull_card_art');
      addTearDown(() => dir.deleteSync(recursive: true));
      final art = File(p.join(dir.path, 'cover.png'))
        ..writeAsBytesSync(kTinyPng);
      ScrapedStore.instance.seed(ScrapedGame(
        romPath: 'snes/beta.sfc',
        title: 'Beta Quest',
        images: {'boxart': art.path},
      ));
      final rom = RomResult(filePath: 'snes/beta.sfc', fileName: 'beta.sfc')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: rom, discs: [rom], memberKey: 'path:snes/beta.sfc'),
        onSearch: () {},
      )));

      // The hero cover comes first; the header thumbnail renders the same file
      // again from its own slot. cacheWidth wraps the FileImage in a ResizeImage.
      final provider =
          (tester.widget<Image>(find.byType(Image).first).image as ResizeImage)
              .imageProvider;
      expect((provider as FileImage).file.path, art.path);
    });

    testWidgets('shows the placeholder icon when neither RA nor imported art exists',
        (tester) async {
      final rom = RomResult(filePath: 'snes/gamma.sfc', fileName: 'gamma.sfc')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: rom, discs: [rom], memberKey: 'path:snes/gamma.sfc'),
        onSearch: () {},
      )));

      expect(find.byIcon(Icons.videogame_asset_outlined), findsOneWidget);
    });
  });

  group('meta line', () {
    testWidgets('fills RA gaps from imported metadata and adds points/players',
        (tester) async {
      ScrapedStore.instance.seed(const ScrapedGame(
        romPath: 'snes/delta.sfc',
        title: 'Delta Run',
        genre: 'Platformer',
        releaseDate: '1994',
        publisher: 'Imported Co',
      ));
      final rom = RomResult(filePath: 'snes/delta.sfc', fileName: 'delta.sfc')
        ..status = RomStatus.supported
        ..gameId = 2
        ..points = 350
        ..numPlayersCasual = 1200;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:2'),
        onSearch: () {},
      )));

      expect(find.textContaining('Platformer'), findsOneWidget);
      expect(find.textContaining('1994'), findsOneWidget);
      expect(find.textContaining('Imported Co'), findsOneWidget);
      expect(find.textContaining('350 pts'), findsOneWidget);
      expect(find.textContaining('1.2K players'), findsOneWidget);
    });

    testWidgets('renders no meta line at all when there is nothing to show',
        (tester) async {
      final rom =
          RomResult(filePath: 'snes/epsilon.sfc', fileName: 'epsilon.sfc')
            ..status = RomStatus.localOnly;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: rom, discs: [rom], memberKey: 'path:snes/epsilon.sfc'),
        onSearch: () {},
      )));

      // The line is joined with ' · ', so a missing part would show up as a
      // dangling or doubled separator rather than as empty text.
      final texts =
          tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);
      expect(texts, isNot(contains('')));
      expect(texts.any((t) => t != null && t.contains('·')), false);
    });
  });

  group('dialog wiring', () {
    testWidgets('passes all discs and onDeleted for a multi-disc card',
        (tester) async {
      final disc1 = RomResult(
          filePath: 'psx/zeta (Disc 1).chd', fileName: 'zeta (Disc 1).chd')
        ..status = RomStatus.supported
        ..gameId = 3;
      final disc2 = RomResult(
          filePath: 'psx/zeta (Disc 2).chd', fileName: 'zeta (Disc 2).chd')
        ..status = RomStatus.supported
        ..gameId = 3;
      var deleted = false;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: disc1, discs: [disc1, disc2], memberKey: 'ra:3'),
        onSearch: () {},
        onDeleted: () => deleted = true,
      )));

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();

      final dlg = tester.widget<GameDetailDialog>(find.byType(GameDetailDialog));
      expect(dlg.discs, hasLength(2));
      dlg.onDeleted?.call();
      expect(deleted, true);
    });

    testWidgets('passes no disc list for a single-disc card', (tester) async {
      final rom = RomResult(filePath: 'psx/mono.chd', fileName: 'mono.chd')
        ..status = RomStatus.supported
        ..gameId = 4;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:4'),
        onSearch: () {},
      )));

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();

      final dlg = tester.widget<GameDetailDialog>(find.byType(GameDetailDialog));
      expect(dlg.discs, isNull);
    });

    testWidgets('tapping the card body does not open the dialog',
        (tester) async {
      final rom = RomResult(filePath: 'snes/theta.sfc', fileName: 'theta.sfc')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: rom, discs: [rom], memberKey: 'path:snes/theta.sfc'),
        onSearch: () {},
      )));

      await tester.tap(find.textContaining('theta'));
      await tester.pump();

      expect(find.byType(GameDetailDialog), findsNothing);
    });
  });

  group('header', () {
    testWidgets('shows the listing thumbnail and file name, not the console',
        (tester) async {
      final rom = RomResult(filePath: 'snes/lambda.sfc', fileName: 'lambda (USA) (Rev 1).sfc')
        ..status = RomStatus.supported
        ..gameId = 8
        ..gameTitle = 'Lambda Quest'
        ..consoleName = 'SNES'
        ..imageIcon = '/Images/lambda_icon.png';
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:8'),
        onSearch: () {},
      )));

      expect(find.text('Lambda Quest'), findsOneWidget);
      expect(find.text('lambda (USA) (Rev 1).sfc'), findsOneWidget);
      expect(find.text('SNES'), findsNothing);
      expect(
          tester
              .widget<RomThumb>(find.byType(RomThumb))
              .raArt,
          '/Images/lambda_icon.png');
    });
  });

  group('image zoom', () {
    testWidgets('RA cover art enlarges in place instead of opening the dialog',
        (tester) async {
      final rom = RomResult(filePath: 'snes/iota.sfc', fileName: 'iota.sfc')
        ..status = RomStatus.supported
        ..gameId = 7
        ..imageBoxArt = '/Images/iota_box.png';
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:7'),
        onSearch: () {},
      )));

      expect(tester.widget<RaImage>(find.byType(RaImage)).zoomable, isTrue);
    });

    testWidgets('imported cover art opens the fullscreen viewer', (tester) async {
      final dir = Directory.systemTemp.createTempSync('cull_card_zoom');
      addTearDown(() => dir.deleteSync(recursive: true));
      final art = File(p.join(dir.path, 'cover.png'))
        ..writeAsBytesSync(kTinyPng);
      ScrapedStore.instance.seed(ScrapedGame(
        romPath: 'snes/kappa.sfc',
        title: 'Kappa Quest',
        images: {'boxart': art.path},
      ));
      final rom = RomResult(filePath: 'snes/kappa.sfc', fileName: 'kappa.sfc')
        ..status = RomStatus.localOnly;
      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(
            rom: rom, discs: [rom], memberKey: 'path:snes/kappa.sfc'),
        onSearch: () {},
      )));

      await tester.tap(find.byType(Image).first); // the hero cover
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(GameDetailDialog), findsNothing);
    });
  });

  group('wide gallery', () {
    // A wide card tiles every other image beside the cover; a narrow one shows
    // the cover alone.
    Widget wide(Widget child) => MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 480, width: 900, child: child),
          ),
        );

    // Paths of images rendered from disk. RaImage builds an Image internally,
    // so the widget type alone does not tell local media from RA art.
    List<String> localPaths(WidgetTester tester) => tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<ResizeImage>()
        .map((r) => r.imageProvider)
        .whereType<FileImage>()
        .map((f) => f.file.path)
        .toList();

    (RomResult, ScrapedGame) shotsFixture(String dirPath) {
      final rom = RomResult(filePath: 'snes/delta.sfc', fileName: 'delta.sfc')
        ..status = RomStatus.supported
        ..gameId = 6
        ..imageBoxArt = '/Images/delta_box.png'
        ..imageTitle = '/Images/delta_title.png'
        ..imageIngame = '/Images/delta_ingame.png'
        ..imageIcon = '/Images/delta_icon.png';
      final scraped = ScrapedGame(
        romPath: 'snes/delta.sfc',
        title: 'Delta Quest',
        images: {
          'screenshot': p.join(dirPath, 'shot.png'),
          'video': p.join(dirPath, 'clip.mp4'),
        },
      );
      return (rom, scraped);
    }

    testWidgets('tiles the RA shots and imported media beside the cover',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('cull_card_gallery');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'shot.png')).writeAsBytesSync(kTinyPng);
      final (rom, scraped) = shotsFixture(dir.path);
      ScrapedStore.instance.seed(scraped);

      await tester.pumpWidget(wide(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:6'),
        onSearch: () {},
      )));

      // Cover plus both RA shots, and the imported screenshot from disk. The
      // video is never rendered, and the icon only appears in the header
      // thumbnail rather than being tiled a second time.
      final urls = tester
          .widgetList<RaImage>(find.byType(RaImage))
          .map((w) => w.url)
          .toList();
      expect(urls, hasLength(4));
      expect(urls.any((u) => u.endsWith('delta_title.png')), isTrue);
      expect(urls.any((u) => u.endsWith('delta_ingame.png')), isTrue);
      expect(
          urls.where((u) => u.endsWith('delta_icon.png')), hasLength(1));
      expect(localPaths(tester), [p.join(dir.path, 'shot.png')]);
    });

    testWidgets('a narrow card shows the cover only', (tester) async {
      final dir = Directory.systemTemp.createTempSync('cull_card_narrow');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'shot.png')).writeAsBytesSync(kTinyPng);
      final (rom, scraped) = shotsFixture(dir.path);
      ScrapedStore.instance.seed(scraped);

      await tester.pumpWidget(_wrap(CullCard(
        card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:6'),
        onSearch: () {},
      )));

      // Hero cover and the header thumbnail; nothing tiled beside them.
      expect(find.byType(RaImage), findsNWidgets(2));
      expect(localPaths(tester), isEmpty);
    });

    testWidgets('the achievement readout sits beside the shots and still fits '
        'a short window', (tester) async {
      final rom = RomResult(filePath: 'snes/delta.sfc', fileName: 'delta.sfc')
        ..status = RomStatus.supported
        ..gameId = 6
        ..imageBoxArt = '/Images/delta_box.png'
        ..imageTitle = '/Images/delta_title.png'
        ..imageIngame = '/Images/delta_ingame.png'
        ..achievementCount = 60
        ..earnedAchievements = 21;

      // The panel is a fixed height under an Expanded grid of shots, so a
      // shallow window is where the column would burst if it ever did.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 380,
            width: 900,
            child: CullCard(
              card: CullCardData(rom: rom, discs: [rom], memberKey: 'ra:6'),
              onSearch: () {},
            ),
          ),
        ),
      ));

      expect(find.text('ACHIEVEMENTS'), findsOneWidget);
      expect(find.text('21/60'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a game with no set gets no achievement readout',
        (tester) async {
      final rom = RomResult(filePath: 'snes/gamma.sfc', fileName: 'gamma.sfc')
        ..status = RomStatus.localOnly;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 480,
            width: 900,
            child: CullCard(
              card: CullCardData(
                  rom: rom, discs: [rom], memberKey: 'path:snes/gamma.sfc'),
              onSearch: () {},
            ),
          ),
        ),
      ));

      expect(find.text('ACHIEVEMENTS'), findsNothing);
    });
  });
}
