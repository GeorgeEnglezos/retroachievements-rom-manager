import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/playlist_toolbar.dart';

void main() {
  Widget host({
    RomFilter filter = const RomFilter(),
    bool grouped = false,
    void Function(RomFilter)? onFilterChanged,
    VoidCallback? onGroupedToggle,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: PlaylistToolbar(
            filter: filter,
            availableGenres: const ['Action'],
            showProgress: true,
            playlists: const [(id: 'fav', name: 'Favorites')],
            grouped: grouped,
            onFilterChanged: onFilterChanged ?? (_) {},
            onGroupedToggle: onGroupedToggle ?? () {},
          ),
        ),
      );

  testWidgets('typing fires onFilterChanged with text', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onFilterChanged: (f) => got = f));
    await tester.enterText(find.byType(TextField), 'delta');
    expect(got?.text, 'delta');
  });

  testWidgets('group toggle fires onGroupedToggle', (tester) async {
    var toggled = false;
    await tester.pumpWidget(host(onGroupedToggle: () => toggled = true));
    await tester.tap(find.text('By system'));
    expect(toggled, isTrue);
  });

  testWidgets('Filters reveals the panel (Genre chip appears)', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Action'), findsNothing);
    await tester.tap(find.text('Filters'));
    await tester.pump();
    expect(find.text('Action'), findsOneWidget);
  });
}
