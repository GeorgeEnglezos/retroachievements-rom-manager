import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/fetch_plan.dart';
import 'package:rarm/widgets/fetch_tasks_dialog.dart';

void main() {
  /// Opens the dialog and hands back a holder the test reads after tapping an
  /// action, since the plan only arrives when the dialog pops.
  Future<List<FetchPlan?>> open(WidgetTester tester,
      {required bool global}) async {
    final captured = <FetchPlan?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => captured
                .add(await showFetchTasksDialog(ctx, global: global)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return captured;
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
  }

  // Expanded, the dialog's content scrolls; a tap on an off-screen tile would
  // land on the barrier and dismiss it instead.
  Future<void> tapVisible(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  // The whole point of the collapse: pressing the one button does the full
  // update without the user answering anything.
  testWidgets('the default press asks nothing and runs everything',
      (tester) async {
    final captured = await open(tester, global: true);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    final plan = captured.single!;
    expect(plan.refresh, isTrue);
    expect(plan.match, isTrue);
    expect(plan.progress, isTrue);
    expect(plan.scope, FetchScope.all);
    // The expensive re-hash and the list override stay off unless asked for.
    expect(plan.matchReFetchAll, isFalse);
    expect(plan.refreshLists, isFalse);
  });

  testWidgets('advanced options are hidden until expanded', (tester) async {
    await open(tester, global: true);
    expect(find.text('Re-hash every ROM'), findsNothing);
    await expand(tester);
    expect(find.text('Re-hash every ROM'), findsOneWidget);
  });

  testWidgets('advanced toggles reach the plan', (tester) async {
    final captured = await open(tester, global: true);
    await expand(tester);
    await tapVisible(tester, 'Re-hash every ROM');
    await tapVisible(tester, 'Force refresh RA game lists');
    await tapVisible(tester, 'Only changed folders');
    await tapVisible(tester, 'Update');

    final plan = captured.single!;
    expect(plan.matchReFetchAll, isTrue);
    expect(plan.refreshLists, isTrue);
    expect(plan.scope, FetchScope.changedFolders);
  });

  // The per-folder view has one folder, so there is no folder set to choose.
  testWidgets('folder scope is offered only on the global run', (tester) async {
    await open(tester, global: false);
    await expand(tester);
    expect(find.text('All folders'), findsNothing);
    expect(find.text('Re-hash every ROM'), findsOneWidget);
  });

  testWidgets('cancel returns no plan', (tester) async {
    final captured = await open(tester, global: true);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(captured.single, isNull);
  });
}
