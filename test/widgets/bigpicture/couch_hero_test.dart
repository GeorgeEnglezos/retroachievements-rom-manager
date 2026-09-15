import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/bigpicture/couch_hero.dart';

RomResult _g(String path, String title) =>
    RomResult(filePath: path, fileName: '$title.sfc')..gameTitle = title;

void main() {
  testWidgets('long-pressing the banner and choosing the menu item ignores it',
      (tester) async {
    var ignored = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CouchHero(
          rom: _g('/a.sfc', 'Alpha'),
          onOpen: () {},
          onIgnore: () => ignored = true,
        ),
      ),
    ));

    await tester.longPress(find.byType(CouchHero));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not interested, show next'));
    await tester.pumpAndSettle();

    expect(ignored, isTrue);
  });

  testWidgets('tapping the banner opens it, not the menu', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CouchHero(
          rom: _g('/a.sfc', 'Alpha'),
          onOpen: () => opened = true,
          onIgnore: () {},
        ),
      ),
    ));

    await tester.tap(find.byType(CouchHero));
    expect(opened, isTrue);
    expect(find.text('Not interested, show next'), findsNothing);
  });
}
