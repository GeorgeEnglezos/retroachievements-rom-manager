import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/widgets/home_search.dart';
import 'package:rarm/widgets/rom_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameEntry _matched(String dir) => GameEntry(
      filePath: '$dir/Blahblah (USA).sfc',
      fileName: 'Blahblah (USA).sfc',
      fileSize: 1024,
      md5: 'abc',
      gameId: 77,
      matched: true,
      noMatch: false,
      lastScanned: DateTime(2026),
      gameInfo: GameInfo(
        gameId: 77,
        title: 'Blahblah',
        consoleName: 'SNES',
        achievementCount: 10,
      ),
      progress: null,
    );

void main() {
  testWidgets('the dialog opened from a search hit carries the row actions',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().clear();
    final dataDir = Directory.systemTemp.createTempSync('hs_data');
    addTearDown(() => dataDir.deleteSync(recursive: true));
    // Seeded as a system file rather than through Library.save(): a widget test
    // that saves and then pumps hangs (see cull_screen_test.dart).
    Directory('${dataDir.path}/data/systems').createSync(recursive: true);
    File('${dataDir.path}/data/systems/snes.json')
        .writeAsStringSync(jsonEncode(SystemData(
      systemId: 'snes',
      systemPath: '${dataDir.path}/SNES',
      games: [_matched('${dataDir.path}/SNES')],
      dismissedDuplicatePairs: const {},
      consoleId: 3,
    ).toJson()));
    final lib = Library(baseDir: dataDir);

    // Real disk IO throughout (library reads, prefs), so the whole pump runs in
    // the real event loop instead of the fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeSearch(
            store: PlaylistStore(),
            onPlaylistChanged: () async {},
            idleActions: const [],
            library: lib,
            child: const SizedBox.shrink(),
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField).first, 'Blahblah');
      // Past the 300ms search debounce. pumpAndSettle is unusable here: the
      // pending-search spinner never settles.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      // Scoped to the results: the search field holds the same string.
      await tester.tap(find.descendant(
          of: find.byType(RomListView), matching: find.text('Blahblah')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // dialog transition
    });

    // All three only render when the call site passes store/onPlaylistChanged/
    // onFetch, which this one used to omit.
    expect(find.widgetWithText(OutlinedButton, 'Favorite'), findsOneWidget);
    expect(find.byTooltip('Add to playlist…'), findsOneWidget);
    expect(find.byTooltip('Sync progress'), findsOneWidget);
  });
}
