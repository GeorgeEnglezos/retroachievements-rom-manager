import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/gamepad_navigator.dart';

void main() {
  // The input logic lives in GamepadMapper (see gamepad_test.dart). Here we only
  // guard the plumbing: the wrapper renders its child and survives the plugin
  // channel being absent under tests (it must not throw on subscribe).
  testWidgets('renders child without the gamepad plugin present',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GamepadNavigator(child: Text('couch')),
    ));
    expect(find.text('couch'), findsOneWidget);
  });
}
