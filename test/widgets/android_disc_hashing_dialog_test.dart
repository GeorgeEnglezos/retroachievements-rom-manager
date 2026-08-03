import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/android_disc_hashing_dialog.dart';

void main() {
  testWidgets('shows the under-development alert once, dismisses on OK',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAndroidDiscHashingUnsupported(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('GameCube & Wii on Android'), findsOneWidget);
    expect(find.textContaining('under development'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('GameCube & Wii on Android'), findsNothing);

    // Session guard: a second call is a no-op.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('GameCube & Wii on Android'), findsNothing);
  });
}
