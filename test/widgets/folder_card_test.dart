import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_stats.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/folder_card.dart';

void main() {
  Widget host(Widget child, {UiTokens? palette}) => MaterialApp(
        theme: palette == null ? null : uiTheme(palette),
        home: Scaffold(body: child),
      );

  testWidgets('unknown folder shows the generic logo, with no badge on it',
      (tester) async {
    await tester.pumpWidget(host(FolderCard(
      name: 'Sega Genesis',
      displayName: 'Sega Genesis',
      stats: FolderStats(path: 'x', totalGames: 3),
      consoleId: null,
      onTap: () {},
    )));
    expect(find.text('Sega Genesis'), findsOneWidget);
    // Falls back to the generic logo (an Image), not a bare help icon. The
    // unsupported systems now sit in their own Library block, so the front of
    // the card carries no badge.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No RetroAchievements'), findsNothing);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(FolderCard(
      name: 'SNES',
      displayName: 'SNES',
      stats: null,
      consoleId: null,
      onTap: () => tapped = true,
    )));
    await tester.tap(find.text('SNES'));
    expect(tapped, isTrue);
  });

  testWidgets('console logo renders full-color (no theme tint)',
      (tester) async {
    await tester.pumpWidget(host(FolderCard(
      name: 'Game Boy',
      displayName: 'Game Boy',
      stats: FolderStats(path: 'x', totalGames: 1),
      consoleId: 4, // maps to a bundled asset -> Image.asset path
      onTap: () {},
    )));
    // Logos are shown in their own colors now, not tinted to the theme ink.
    expect(tester.widget<Image>(find.byType(Image)).color, isNull);
  });

  testWidgets('shows subtitle under the name when provided', (tester) async {
    await tester.pumpWidget(host(FolderCard(
      name: 'PlayStation',
      displayName: 'PlayStation',
      stats: FolderStats(path: 'x', totalGames: 3),
      consoleId: null,
      subtitle: '3 folders',
      onTap: () {},
    )));
    expect(find.text('3 folders'), findsOneWidget);
  });

  testWidgets('FolderRow shows everything the card keeps on its back',
      (tester) async {
    await tester.pumpWidget(host(FolderRow(
      name: 'snes',
      displayName: 'Super Nintendo',
      stats: FolderStats(
        path: 'x',
        totalGames: 4,
        totalSizeBytes: 2 * 1024 * 1024,
        gamesWithAchievements: 2,
        gamesScanned: 4,
        lastScanned: DateTime(2026, 1, 1),
      ),
      consoleId: 3,
      onTap: () {},
    )));
    expect(find.text('Super Nintendo'), findsOneWidget);
    expect(find.text('snes'), findsOneWidget); // raw folder name
    expect(find.text('4 games'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('FolderRow hides the folder name when it matches the label',
      (tester) async {
    await tester.pumpWidget(host(FolderRow(
      name: 'Game Boy',
      displayName: 'Game Boy',
      stats: FolderStats(path: 'x', totalGames: 1),
      consoleId: 4,
      onTap: () {},
    )));
    expect(find.text('Game Boy'), findsOneWidget);
    expect(find.text('Not scanned yet'), findsOneWidget);
  });

  // The cards sit on a fixed light plate, so their labels must stay dark ink in
  // every palette. A Theme override alone doesn't do it: an unstyled Text reads
  // the DefaultTextStyle of the Scaffold's Material, outside the card.
  testWidgets('system label keeps light ink under any palette', (tester) async {
    Future<Color?> labelColor(UiTokens palette, Widget card) async {
      await tester.pumpWidget(host(card, palette: palette));
      return tester
          .renderObject<RenderParagraph>(find.text('PlayStation'))
          .text
          .style
          ?.color;
    }

    Widget card() => FolderCard(
          name: 'psx',
          displayName: 'PlayStation',
          stats: FolderStats(path: 'x', totalGames: 3),
          consoleId: null,
          onTap: () {},
        );
    final onDark = await labelColor(UiTokens.dark, card());
    final onLight = await labelColor(UiTokens.light, card());
    expect(onDark, onLight);
    expect(onDark, uiTheme(UiTokens.light).textTheme.bodyMedium!.color);
    expect(onDark, isNot(UiTokens.dark.text));
  });

  testWidgets('FolderRow label keeps light ink under any palette',
      (tester) async {
    Future<Color?> labelColor(UiTokens palette) async {
      await tester.pumpWidget(host(
        FolderRow(
          name: 'psx',
          displayName: 'PlayStation',
          stats: FolderStats(path: 'x', totalGames: 3),
          consoleId: null,
          onTap: () {},
        ),
        palette: palette,
      ));
      return tester
          .renderObject<RenderParagraph>(find.text('PlayStation'))
          .text
          .style
          ?.color;
    }

    expect(await labelColor(UiTokens.dark), await labelColor(UiTokens.light));
    expect(await labelColor(UiTokens.dark),
        uiTheme(UiTokens.light).textTheme.bodyMedium!.color);
  });

  testWidgets('FolderRow tapping calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(FolderRow(
      name: 'SNES',
      displayName: 'SNES',
      stats: null,
      consoleId: null,
      onTap: () => tapped = true,
    )));
    await tester.tap(find.text('SNES'));
    expect(tapped, isTrue);
  });
}
