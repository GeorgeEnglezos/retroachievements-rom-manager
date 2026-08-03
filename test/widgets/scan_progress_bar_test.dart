import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/scan_progress_bar.dart';

void main() {
  // Singleton, so every test starts from a stopped bar.
  setUp(() => ScanProgress.instance.stop());
  tearDown(() => ScanProgress.instance.stop());

  Future<void> pumpBar(WidgetTester tester) => tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScanProgressBar())));

  testWidgets('renders nothing while no scan is running', (tester) async {
    await pumpBar(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('shows the published label and progress', (tester) async {
    ScanProgress.instance
        .publish(running: true, value: 0.5, label: 'System 1/3: NES');
    await pumpBar(tester);

    expect(find.text('System 1/3: NES'), findsOneWidget);
    expect(
        tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator)).value,
        0.5);
  });

  // Spamming Cancel must not queue up cancels, and the button has to say the
  // press landed: silence is what makes users hammer it.
  testWidgets('cancel fires once and then reads as cancelling', (tester) async {
    var cancels = 0;
    ScanProgress.instance
        .publish(running: true, label: 'x', onCancel: () => cancels++);
    await pumpBar(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancels, 1);
    expect(find.text('Cancelling…'), findsOneWidget);

    // Later progress ticks keep the cancelling state.
    ScanProgress.instance
        .publish(running: true, label: 'y', onCancel: () => cancels++);
    await tester.pump();
    await tester.tap(find.text('Cancelling…'));
    await tester.pump();
    expect(cancels, 1);
  });

  testWidgets('a new run clears the cancelling state', (tester) async {
    var cancels = 0;
    ScanProgress.instance
        .publish(running: true, label: 'x', onCancel: () => cancels++);
    await pumpBar(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    ScanProgress.instance.stop();
    ScanProgress.instance
        .publish(running: true, label: 'x', onCancel: () => cancels++);
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancels, 2);
  });
}
