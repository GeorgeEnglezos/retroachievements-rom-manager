import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/active_filter_chips.dart';

void main() {
  Widget host(RomFilter filter, void Function(RomFilter) onChanged) =>
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: activeFilterChips(
              filter: filter,
              playlists: const [(id: 'fav', name: 'Favorites')],
              onChanged: onChanged,
            ),
          ),
        ),
      );

  testWidgets('empty filter produces no chips', (tester) async {
    await tester.pumpWidget(host(const RomFilter(), (_) {}));
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('renders a chip per active criterion', (tester) async {
    await tester.pumpWidget(host(
      const RomFilter(
        statuses: {RomStatus.supported},
        includePlaylistIds: {'fav'},
      ),
      (_) {},
    ));
    expect(find.text('Supported'), findsOneWidget);
    expect(find.text('Favorites: only'), findsOneWidget);
  });

  testWidgets('removing a status chip clears that status', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(
      const RomFilter(statuses: {RomStatus.supported}),
      (f) => got = f,
    ));
    await tester.tap(find.byIcon(Icons.close).first);
    expect(got?.statuses.contains(RomStatus.supported), isFalse);
  });
}
