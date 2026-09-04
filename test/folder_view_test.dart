import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/screens/folder_view.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/widgets/fetch_fab.dart';
import 'package:rarm/widgets/folder_toolbar.dart';

void main() {
  testWidgets('lists ROM files from every folder path', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Sync IO: an awaited async filesystem call would deadlock under the
    // testWidgets fake clock.
    final root = Directory.systemTemp.createTempSync('fv_test');
    final a = Directory('${root.path}/PS1 USA')..createSync();
    final b = Directory('${root.path}/PS1 Eur')..createSync();
    File('${a.path}/Crash (USA).bin').writeAsStringSync('x');
    File('${b.path}/Crash (Eur).bin').writeAsStringSync('x');

    // The library uses getApplicationSupportDirectory() by default, which has
    // no plugin in widget tests; back it with a temp dir instead.
    final dataDir = Directory.systemTemp.createTempSync('fv_data');

    // listRomFiles uses real async IO (Directory.list stream + file.length()).
    // The entire widget pump must happen inside runAsync so that real IO
    // futures complete in the real event loop rather than the fake-async zone.
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: FolderView(
          folderPaths: [a.path, b.path],
          title: 'PlayStation',
          consoleId: 12,
          enabledExtensions: const {'bin'},
          library: Library(baseDir: dataDir),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('PlayStation'), findsOneWidget); // app bar title
    expect(find.text('Crash (USA).bin'), findsOneWidget);
    expect(find.text('Crash (Eur).bin'), findsOneWidget);

    root.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
  });

  testWidgets('showActions:false hides the fetch entry point', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory.systemTemp.createTempSync('fv_noact');
    final a = Directory('${root.path}/SNES')..createSync();
    File('${a.path}/Blahblah (USA).sfc').writeAsStringSync('x');
    final dataDir = Directory.systemTemp.createTempSync('fv_noact_data');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: FolderView(
          folderPaths: [a.path],
          title: 'All games',
          enabledExtensions: const {'sfc'},
          library: Library(baseDir: dataDir),
          showActions: false,
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('Blahblah (USA).sfc'), findsOneWidget); // rendered
    expect(find.byType(FetchFab), findsNothing); // but no fetch entry point

    root.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
  });

  testWidgets('the search & filters toolbar collapses and reappears',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final root = Directory.systemTemp.createTempSync('fv_collapse');
    final a = Directory('${root.path}/SNES')..createSync();
    File('${a.path}/Game (USA).sfc').writeAsStringSync('x');
    final dataDir = Directory.systemTemp.createTempSync('fv_collapse_data');

    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: FolderView(
          folderPaths: [a.path],
          title: 'SNES',
          enabledExtensions: const {'sfc'},
          library: Library(baseDir: dataDir),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.byType(FolderToolbar), findsNothing); // hidden by default
    expect(find.text('Game (USA).sfc'), findsOneWidget); // list still there

    await tester.tap(find.byKey(const Key('toolbar_toggle')));
    await tester.pump();
    expect(find.byType(FolderToolbar), findsOneWidget);

    await tester.tap(find.byKey(const Key('toolbar_toggle')));
    await tester.pump();
    expect(find.byType(FolderToolbar), findsNothing);

    root.deleteSync(recursive: true);
    dataDir.deleteSync(recursive: true);
  });
}
