import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_stats.dart';
import 'package:rarm/widgets/folder_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('unknown folder shows generic logo and unsupported chip',
      (tester) async {
    await tester.pumpWidget(host(FolderCard(
      name: 'Sega Genesis',
      displayName: 'Sega Genesis',
      stats: FolderStats(path: 'x', totalGames: 3),
      consoleId: null,
      onTap: () {},
    )));
    expect(find.text('Sega Genesis'), findsOneWidget);
    // Falls back to the generic logo (an Image), not a bare help icon, and is
    // marked as not RA-supported.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('No RetroAchievements'), findsOneWidget);
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
