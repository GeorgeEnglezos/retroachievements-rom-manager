import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/ui/ui_segmented.dart';

void main() {
  testWidgets('tapping a segment fires onChanged with its value', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiSegmented<int>(
          value: 0,
          segments: const [
            (value: 0, label: 'List', icon: null),
            (value: 1, label: 'Grid', icon: null),
          ],
          onChanged: (v) => picked = v,
        ),
      ),
    ));
    await tester.tap(find.text('Grid'));
    expect(picked, 1);
  });

  testWidgets('disabled segmented does not fire onChanged', (tester) async {
    int? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: UiSegmented<int>(
          value: 0,
          enabled: false,
          segments: const [
            (value: 0, label: 'List', icon: null),
            (value: 1, label: 'Grid', icon: null),
          ],
          onChanged: (v) => picked = v,
        ),
      ),
    ));
    await tester.tap(find.text('Grid'));
    expect(picked, isNull);
  });
}
