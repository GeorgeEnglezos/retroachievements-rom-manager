import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_sort.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/cleanup_score.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/folder_toolbar.dart';

void main() {
  Widget host({
    RomFilter filter = const RomFilter(),
    FolderSort sort = FolderSort.alphabetical,
    bool anyDuplicates = true,
    bool actionsEnabled = true,
    bool showActions = true,
    CleanupScoreMode cleanupMode = CleanupScoreMode.logDampened,
    void Function(RomFilter)? onFilterChanged,
    void Function(FolderSort)? onSortChanged,
    void Function(CleanupScoreMode)? onCleanupModeChanged,
    void Function(bool)? onDuplicatesToggle,
    void Function(bool)? onHotToggle,
    VoidCallback? onRunActions,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: FolderToolbar(
            filter: filter,
            sort: sort,
            sortAscending: true,
            gridView: false,
            availableGenres: const ['Action'],
            showProgress: true,
            anyDuplicates: anyDuplicates,
            cleanupMode: cleanupMode,
            playlists: const [(id: 'fav', name: 'Favorites')],
            showActions: showActions,
            actionsEnabled: actionsEnabled,
            onFilterChanged: onFilterChanged ?? (_) {},
            onSortChanged: onSortChanged ?? (_) {},
            onCleanupModeChanged: onCleanupModeChanged ?? (_) {},
            onDirectionToggle: () {},
            onViewToggle: () {},
            onDuplicatesToggle: onDuplicatesToggle ?? (_) {},
            onHotToggle: onHotToggle ?? (_) {},
            onRunActions: onRunActions ?? () {},
          ),
        ),
      );

  testWidgets('typing in search fires onFilterChanged with text', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onFilterChanged: (f) => got = f));
    await tester.enterText(find.byType(TextField), 'delta');
    expect(got?.text, 'delta');
  });

  testWidgets('Actions button fires onRunActions', (tester) async {
    var ran = false;
    await tester.pumpWidget(host(onRunActions: () => ran = true));
    await tester.tap(find.text('Actions'));
    expect(ran, isTrue);
  });

  testWidgets('Duplicates toggle fires onDuplicatesToggle(true)', (tester) async {
    bool? got;
    await tester.pumpWidget(host(onDuplicatesToggle: (v) => got = v));
    await tester.tap(find.text('Duplicates'));
    expect(got, isTrue);
  });

  testWidgets('Duplicates toggle hidden when no duplicates', (tester) async {
    await tester.pumpWidget(host(anyDuplicates: false));
    expect(find.text('Duplicates'), findsNothing);
  });

  testWidgets('sort dropdown disabled while duplicates active', (tester) async {
    await tester.pumpWidget(host(
      filter: const RomFilter(onlyDuplicates: true),
      onSortChanged: (_) => fail('sort should be disabled'),
    ));
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(find.text('Points'), findsNothing); // menu did not open
  });

  testWidgets('opening Filters reveals the Status section', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Filters'));
    await tester.pump();
    expect(find.text('Supported'), findsOneWidget);
  });

  testWidgets('Actions button disabled when actionsEnabled is false',
      (tester) async {
    var ran = false;
    await tester.pumpWidget(host(
      actionsEnabled: false,
      onRunActions: () => ran = true,
    ));
    await tester.tap(find.text('Actions'), warnIfMissed: false);
    expect(ran, isFalse);
  });

  testWidgets('Cleanup is offered as a sort option', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(find.text('Cleanup'), findsOneWidget);
  });

  testWidgets('cleanup mode picker shown only when Cleanup sort active',
      (tester) async {
    await tester.pumpWidget(host(sort: FolderSort.alphabetical));
    expect(find.text('Log-dampened'), findsNothing);

    await tester.pumpWidget(host(sort: FolderSort.cleanup));
    expect(find.text('Log-dampened'), findsOneWidget);
  });

  testWidgets('cleanup sort shows no target input (pure score sort)',
      (tester) async {
    await tester.pumpWidget(host(
      sort: FolderSort.cleanup,
      cleanupMode: CleanupScoreMode.ratio,
    ));
    // Ratio mode used to add a target field; now only the search field remains.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('players / yr'), findsNothing);
  });

  testWidgets('Actions button hidden when showActions is false',
      (tester) async {
    await tester.pumpWidget(host(showActions: false));
    expect(find.text('Actions'), findsNothing);
  });

  testWidgets('active status chip removal clears that status', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(
      filter: const RomFilter(statuses: {RomStatus.supported}),
      onFilterChanged: (f) => got = f,
    ));
    await tester.tap(find.byIcon(Icons.close).first);
    expect(got?.statuses.contains(RomStatus.supported), isFalse);
  });
}
