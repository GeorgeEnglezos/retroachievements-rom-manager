import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/scan_progress.dart';
import 'package:rarm/widgets/fetch_fab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ScanProgress.instance.stop();
  });
  tearDown(() => ScanProgress.instance.stop());

  Future<void> pump(WidgetTester tester, {VoidCallback? onPressed}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: FetchFab(onPressed: onPressed ?? () {}),
        ),
      ));

  testWidgets('shows the refresh icon before an avatar resolves',
      (tester) async {
    await pump(tester);
    await tester.pump();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('fires onPressed when idle', (tester) async {
    var ran = false;
    await pump(tester, onPressed: () => ran = true);
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    expect(ran, isTrue);
  });

  // Two runs writing the same SystemData is the bug this prevents.
  testWidgets('is disabled while a run holds the progress bar', (tester) async {
    var ran = false;
    ScanProgress.instance.publish(running: true, label: 'scanning');
    await pump(tester, onPressed: () => ran = true);
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    expect(ran, isFalse);
  });
}
