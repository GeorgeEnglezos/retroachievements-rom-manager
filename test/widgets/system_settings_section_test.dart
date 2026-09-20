import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/services/emulator_store.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:rarm/services/scan_settings.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/system_settings_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late Directory dataDir;
  late Library lib;

  // A system holding [games] ROM files, saved the way a scan would leave it.
  Future<void> seed(String folder, int games) async {
    final dir = Directory(p.join(root.path, folder))..createSync();
    final entries = <GameEntry>[];
    for (var i = 0; i < games; i++) {
      final file = File(p.join(dir.path, 'game$i.bin'))..writeAsStringSync('x');
      entries.add(GameEntry.unscanned(file.path, fileSize: 1));
    }
    await lib.save(SystemData(
      systemId: '',
      systemPath: dir.path,
      games: entries,
      dismissedDuplicatePairs: <String>{},
      consoleId: null,
    ));
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('rarm_systems_tab');
    // Separate from the ROM root: the library writes its own data/ folder into
    // baseDir, which has no business showing up as a system.
    dataDir = Directory.systemTemp.createTempSync('rarm_systems_data');
    SharedPreferences.setMockInitialValues({PrefKeys.lastFolder: root.path});
    await ScanSettings.setIgnoredFolders('BIOS');
    lib = Library(baseDir: dataDir);

    await seed('snes', 2); // recognised, RA-hashable
    await seed('ps3', 1); // recognised, display-only (no RetroAchievements)
    await seed('empty-system', 0); // a folder with no ROMs left in it
    await seed('BIOS', 3); // ignored by name
  });

  tearDown(() {
    root.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
  });

  Widget host() => MaterialApp(
        theme: uiTheme(UiTokens.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSettingsSection(library: lib),
          ),
        ),
      );

  // The section reads the library off disk, and dart:io futures only complete
  // on the real event loop; outside runAsync the load never finishes. Poll
  // rather than sleeping a fixed span, which races a loaded CI box.
  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(host());
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('snes').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('system cards never loaded');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  // The whole point of this tab being built on Library.summaries(): it shows
  // exactly the systems the home grid shows, no more.
  testWidgets('lists only the systems the rest of the app shows',
      (tester) async {
    await pumpUntilLoaded(tester);

    expect(find.text('snes'), findsOneWidget);
    // Display-only consoles still belong here: you pick their emulator too.
    expect(find.text('ps3'), findsOneWidget);
    expect(find.text('No RetroAchievements'), findsOneWidget);

    // A folder with no ROMs is not a system anywhere else, so not here either.
    expect(find.text('empty-system'), findsNothing);
    expect(find.text('BIOS'), findsNothing);
  });

  // The inventory and the system rows are one tab and one emulator list: an
  // emulator registered above is immediately pickable on every card below.
  testWidgets('emulators in the inventory are offered to every system',
      (tester) async {
    // A kind the catalog has no console defaults for, so nothing auto-connects
    // and the dropdown genuinely starts unset.
    await EmulatorStore.addEmulator(Emulator(
      id: 'e1',
      name: 'TestBox',
      exePath: p.join('C:', 'emus', 'testbox.exe'),
      kindId: 'testbox',
    ));

    await pumpUntilLoaded(tester);

    // The inventory row. A closed dropdown only renders its selected item, so
    // the cards' copies appear once the menu below is opened.
    expect(find.text('TestBox'), findsOneWidget);

    await tester.tap(find.byKey(const Key('emulator-snes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TestBox').last);
    await tester.pumpAndSettle();

    expect((await EmulatorStore.connectedEmulator(3))?.name, 'TestBox');
  });

  testWidgets('picking a console persists an override for that folder',
      (tester) async {
    await pumpUntilLoaded(tester);

    expect(await ScanSettings.consoleIdForFolder('snes'), 3); // auto-detected

    await tester.tap(find.byKey(const Key('console-snes')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nintendo 64').last);
    await tester.pumpAndSettle();

    expect(await ScanSettings.consoleIdForFolder('snes'), 2);
  });
}
