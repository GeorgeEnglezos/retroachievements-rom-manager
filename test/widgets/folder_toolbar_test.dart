import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_sort.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/folder_toolbar.dart';

void main() {
  Widget host({
    RomFilter filter = const RomFilter(),
    FolderSort sort = FolderSort.alphabetical,
    bool anyDuplicates = true,
    bool showViewToggle = true,
    bool gridView = false,
    void Function(RomFilter)? onFilterChanged,
    void Function(FolderSort)? onSortChanged,
    void Function(bool)? onDuplicatesToggle,
    void Function(bool)? onHotToggle,
    void Function(double)? onGridSizeChanged,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: FolderToolbar(
            filter: filter,
            sort: sort,
            sortAscending: true,
            gridView: gridView,
            showViewToggle: showViewToggle,
            availableGenres: const ['Action'],
            showProgress: true,
            anyDuplicates: anyDuplicates,
            gridSize: FolderToolbar.gridSizeDefault,
            onGridSizeChanged: onGridSizeChanged,
            playlists: const [(id: 'fav', name: 'Favorites')],
            onFilterChanged: onFilterChanged ?? (_) {},
            onSortChanged: onSortChanged ?? (_) {},
            onDirectionToggle: () {},
            onViewToggle: () {},
            onDuplicatesToggle: onDuplicatesToggle ?? (_) {},
            onHotToggle: onHotToggle ?? (_) {},
          ),
        ),
      );

  testWidgets('typing in search fires onFilterChanged with text', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onFilterChanged: (f) => got = f));
    await tester.enterText(find.byType(TextField), 'delta');
    expect(got?.text, 'delta');
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
    expect(find.text('Least played'), findsNothing); // menu did not open
  });

  testWidgets('opening Filters reveals the Status section', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Filters'));
    await tester.pump();
    expect(find.text('Supported'), findsOneWidget);
  });

  testWidgets('Least played is offered as a sort option', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(find.text('Least played'), findsOneWidget);
  });

  testWidgets('least-played sort adds no extra controls (pure score sort)',
      (tester) async {
    await tester.pumpWidget(host(sort: FolderSort.leastPlayed));
    // Only the search field; the scoring mode is fixed, not user-pickable.
    expect(find.byType(TextField), findsOneWidget);
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

  testWidgets('the grid-size slider shows only in grid view and reports drags',
      (tester) async {
    double? got;
    // List view: no slider.
    await tester.pumpWidget(host(onGridSizeChanged: (v) => got = v));
    expect(find.byType(Slider), findsNothing);

    // Grid view: the slider appears and a drag fires onGridSizeChanged.
    await tester.pumpWidget(
        host(gridView: true, onGridSizeChanged: (v) => got = v));
    expect(find.byType(Slider), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(-40, 0));
    expect(got, isNotNull);
    expect(got, lessThan(FolderToolbar.gridSizeDefault)); // dragged smaller
  });

  testWidgets('a pinned play layout hides the list/grid toggle', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byIcon(Icons.grid_view), findsOneWidget);

    await tester.pumpWidget(host(showViewToggle: false));
    expect(find.byIcon(Icons.grid_view), findsNothing);
    // The rest of the toolbar is untouched.
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });
}
