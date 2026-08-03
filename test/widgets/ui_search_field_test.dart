import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/ui/ui_search_field.dart';

void main() {
  testWidgets('typing fires onChanged with the text', (tester) async {
    final controller = TextEditingController();
    String? got;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiSearchField(
          controller: controller,
          hintText: 'Search',
          onChanged: (v) => got = v,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'racer');
    expect(got, 'racer');
  });

  testWidgets('clear button appears when non-empty and clears + fires onChanged',
      (tester) async {
    final controller = TextEditingController(text: 'quest');
    String? got;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiSearchField(
          controller: controller,
          hintText: 'Search',
          onChanged: (v) => got = v,
        ),
      ),
    ));
    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(got, '');
    expect(find.byIcon(Icons.clear), findsNothing);
  });
}
