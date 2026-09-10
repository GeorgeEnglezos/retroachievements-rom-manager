import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/widgets/bigpicture/cover_row.dart';

// Art left null so tiles render their placeholder, never a network image.
RomResult _g(String path, String title) =>
    RomResult(filePath: path, fileName: '$title.sfc')..gameTitle = title;

void main() {
  testWidgets('renders one tile per game and reports the opened rom',
      (tester) async {
    RomResult? opened;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoverRow(
          title: 'Jump back in',
          games: [_g('/a.sfc', 'Alpha'), _g('/b.sfc', 'Beta')],
          onOpen: (r) => opened = r,
        ),
      ),
    ));

    expect(find.text('Jump back in'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    expect(opened?.filePath, '/a.sfc');
  });

  testWidgets('an empty row renders nothing (no header)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CoverRow(title: 'Jump back in', games: [], onOpen: _noop),
      ),
    ));
    expect(find.text('Jump back in'), findsNothing);
  });
}

void _noop(RomResult _) {}
