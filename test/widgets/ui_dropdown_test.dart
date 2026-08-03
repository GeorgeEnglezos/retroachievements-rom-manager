import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/ui/ui_dropdown.dart';

void main() {
  testWidgets('shows current label and fires onChanged on selection',
      (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiDropdown<int>(
          value: 0,
          items: const [
            (value: 0, label: 'Name'),
            (value: 1, label: 'Points'),
          ],
          onChanged: (v) => picked = v,
        ),
      ),
    ));
    expect(find.text('Name'), findsOneWidget);
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Points').last);
    await tester.pumpAndSettle();
    expect(picked, 1);
  });
}
