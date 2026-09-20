import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/screens/cull_screen.dart';
import 'package:rarm/services/cull_store.dart';
import 'package:rarm/services/library.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The picker loads the library from disk, and real IO futures never complete in
// the fake-async zone testWidgets runs in, so the pump has to happen inside
// runAsync with a real delay; the plain pump() after it applies the setState
// that woke up (same pattern as folder_view_test.dart).
//
// Only the empty state is covered here. A populated library needs
// Library.save(), and a widget test that writes system files then pumps this
// screen hangs rather than settling, so the row rendering and the decided/total
// counts are left to the deck-builder and cull-store unit tests plus a manual
// pass in the app.
void main() {
  testWidgets('shows the empty message when no systems are scanned',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    CullStore().clear();
    final dataDir = Directory.systemTemp.createTempSync('cull_screen_empty');
    addTearDown(() => dataDir.deleteSync(recursive: true));

    await tester.runAsync(() async {
      await tester.pumpWidget(
          MaterialApp(home: CullScreen(library: Library(baseDir: dataDir))));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.textContaining('No scanned systems yet'), findsOneWidget);
  });
}
