import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/filter_panel.dart';

void main() {
  Widget host({
    RomFilter filter = const RomFilter(),
    bool showProgress = true,
    List<String> genres = const ['Action'],
    void Function(RomFilter)? onChanged,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: FilterPanel(
            filter: filter,
            availableGenres: genres,
            showProgress: showProgress,
            playlists: const [(id: 'fav', name: 'Favorites')],
            onChanged: onChanged ?? (_) {},
          ),
        ),
      );

  testWidgets('tapping a status chip toggles that status', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onChanged: (f) => got = f));
    await tester.tap(find.text('Supported'));
    expect(got?.statuses, {RomStatus.supported});
  });

  testWidgets('tapping a genre chip toggles that genre', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onChanged: (f) => got = f));
    await tester.tap(find.text('Action'));
    expect(got?.genres, {'Action'});
  });

  testWidgets('progress section hidden when showProgress is false',
      (tester) async {
    await tester.pumpWidget(host(showProgress: false));
    expect(find.text('Not started'), findsNothing);
  });

  testWidgets('selecting playlist "only" adds an include id', (tester) async {
    RomFilter? got;
    await tester.pumpWidget(host(onChanged: (f) => got = f));
    await tester.tap(find.text('Favorites: show all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites: only').last);
    await tester.pumpAndSettle();
    expect(got?.includePlaylistIds, {'fav'});
  });
}
