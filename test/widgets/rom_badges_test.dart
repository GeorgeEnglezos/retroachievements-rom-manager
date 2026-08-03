import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/rom_badges.dart';

void main() {
  testWidgets('discBadge renders for 2+ discs, nothing below', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          final ui = context.ui;
          return Column(children: [
            discBadge(3, ui) ?? const Text('none-3'),
            discBadge(1, ui) ?? const Text('none-1'),
            discBadge(null, ui) ?? const Text('none-null'),
          ]);
        }),
      ),
    ));
    expect(find.text('💿 3'), findsOneWidget);
    expect(find.text('none-1'), findsOneWidget); // count < 2 → null
    expect(find.text('none-null'), findsOneWidget);
  });

  testWidgets('noAchBadge renders for unsupported/localOnly/metadataOnly',
      (tester) async {
    RomResult rom(RomStatus s) =>
        RomResult(filePath: 'a', fileName: 'a')..status = s;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          noAchBadge(rom(RomStatus.unsupported)) ?? const Text('none-1'),
          noAchBadge(rom(RomStatus.localOnly)) ?? const Text('none-2'),
          noAchBadge(rom(RomStatus.metadataOnly)) ?? const Text('none-3'),
          noAchBadge(rom(RomStatus.supported)) ?? const Text('none-supported'),
          noAchBadge(rom(RomStatus.notFetched)) ?? const Text('none-fetched'),
        ]),
      ),
    ));
    expect(find.text('NO ACH'), findsNWidgets(3));
    expect(find.text('none-supported'), findsOneWidget);
    expect(find.text('none-fetched'), findsOneWidget);
  });
}
