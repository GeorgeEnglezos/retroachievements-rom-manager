import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/play_view.dart';
import 'package:rarm/screens/home_screen.dart';
import 'package:rarm/widgets/app_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appModeListenable.value = AppMode.cleaning;
  });
  tearDown(() {
    appModeListenable.value = AppMode.cleaning;
    playViewListenable.value = const PlayView();
  });

  void sizePhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('phone nav names every destination for a screen reader',
      (tester) async {
    // The bottom bar is icon-only, so the destination name exists nowhere on
    // screen. Without these labels it is seven unnamed buttons under TalkBack.
    final semantics = tester.ensureSemantics();
    sizePhone(tester);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    for (final name in const [
      'HOME',
      'LIBRARY',
      'PLAY NEXT',
      'CULL',
      'STORAGE',
      'LOGS',
      'SETTINGS',
    ]) {
      expect(find.bySemanticsLabel(name), findsWidgets, reason: name);
    }
    semantics.dispose();
  });

  testWidgets('gaming mode drops the maintenance destinations',
      (tester) async {
    final semantics = tester.ensureSemantics();
    sizePhone(tester);

    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    appModeListenable.value = AppMode.gaming;
    await tester.pump();

    for (final name in const ['HOME', 'LIBRARY', 'PLAY NEXT', 'SETTINGS']) {
      expect(find.bySemanticsLabel(name), findsWidgets, reason: name);
    }
    for (final name in const ['CULL', 'STORAGE', 'LOGS']) {
      expect(find.bySemanticsLabel(name), findsNothing, reason: name);
    }
    semantics.dispose();
  });

  testWidgets('a hidden tab is left behind, and returned to on the way back',
      (tester) async {
    sizePhone(tester);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    // Tap LOGS (index 5), a cleaning-only destination.
    await tester.tap(find.byIcon(Icons.receipt_long));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 5);

    appModeListenable.value = AppMode.gaming;
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    appModeListenable.value = AppMode.cleaning;
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 5);
  });

  testWidgets('a settings change rebuilds the screens under the shell',
      (tester) async {
    // The screens live in an IndexedStack and are never popped, so the only
    // thing that carries a mode or play-view change down to them is this
    // rebuild. Const children would be canonicalized to one instance and
    // Element.updateChild would skip the whole subtree.
    sizePhone(tester);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();

    final before =
        tester.widget(find.byType(HomeScreen, skipOffstage: false));
    playViewListenable.value = const PlayView(hot: false);
    await tester.pump();
    final after = tester.widget(find.byType(HomeScreen, skipOffstage: false));

    expect(identical(before, after), isFalse);
  });
}
