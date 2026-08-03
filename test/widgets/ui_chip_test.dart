import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/ui/ui_chip.dart';

void main() {
  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiChip(label: 'Action', onTap: () => tapped = true),
      ),
    ));
    await tester.tap(find.text('Action'));
    expect(tapped, isTrue);
  });

  testWidgets('shows remove icon and fires onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiChip(
          label: 'Supported',
          selected: true,
          onRemove: () => removed = true,
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(removed, isTrue);
  });

  testWidgets('no remove icon when onRemove is null', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UiChip(label: 'Plain')),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
