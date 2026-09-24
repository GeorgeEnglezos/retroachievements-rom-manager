import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/screens/home_screen.dart';
import 'package:rarm/screens/setup_wizard.dart';
import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/credentials.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/scan_settings.dart';
import 'package:rarm/services/scraper/gamelist_importer.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/ui/ui_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecretStore.resetForTest();
  });

  // The wizard is a modal, so every test opens it the way the app does: over
  // a live route it pops back to when finished.
  Future<void> open(WidgetTester tester,
      [SetupWizard wizard = const SetupWizard()]) async {
    await tester.pumpWidget(MaterialApp(
      theme: uiTheme(UiTokens.light),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSetupWizard(context, wizard),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  // Continue is disabled by a null onPressed.
  bool continueEnabled(WidgetTester tester) =>
      tester
          .widget<UiButton>(find.widgetWithText(UiButton, 'CONTINUE'))
          .onPressed !=
      null;

  testWidgets('skipping marks setup done so it never shows again',
      (tester) async {
    await open(tester);
    await tester.pump();

    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(find.byType(SetupWizard), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefKeys.setupDone), isTrue);
  });

  testWidgets('starts on the welcome step and can advance', (tester) async {
    await open(tester);
    await tester.pump();

    expect(
        find.text('Welcome to Retroachievements Rom Manager'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
  });

  testWidgets('back returns to the previous step', (tester) async {
    await open(tester);
    await tester.pump();

    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(
        find.text('Welcome to Retroachievements Rom Manager'), findsOneWidget);
  });

  testWidgets('a rejected key blocks the step and saves nothing',
      (tester) async {
    await open(tester, SetupWizard(
      verifyCredentials: (u, k) async => throw Exception('HTTP 401'),
    ));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('setup-username')), 'player');
    await tester.enterText(find.byKey(const Key('setup-apikey')), 'wrong');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't sign in"), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raUsername), isNull);
    expect(await readApiKey(), '');
  });

  testWidgets('a verified key saves username, key and avatar path',
      (tester) async {
    await open(tester, SetupWizard(
      verifyCredentials: (u, k) async => '/UserPic/Player.png',
    ));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('setup-username')), 'player');
    await tester.enterText(find.byKey(const Key('setup-apikey')), 'good');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raUsername), 'player');
    // Checked before readApiKey(), which would migrate a plaintext write away
    // and hide it. Reading the key back is not enough on its own.
    expect(prefs.getString(PrefKeys.raApiKey), isNull,
        reason: 'the key must never touch the plaintext pref on the way in');
    expect(await readApiKey(), 'good');
    // RA's media host is case-sensitive, so the authoritative path is stored
    // rather than one rebuilt from the typed username.
    expect(prefs.getString(PrefKeys.raAvatarPath), '/UserPic/Player.png');
  });

  testWidgets('credentials entered before skipping are kept', (tester) async {
    await open(tester, SetupWizard(
      verifyCredentials: (u, k) async => '/UserPic/Player.png',
    ));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('setup-username')), 'player');
    await tester.enterText(find.byKey(const Key('setup-apikey')), 'good');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip setup'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raUsername), 'player');
    expect(prefs.getBool(PrefKeys.setupDone), isTrue);
  });

  testWidgets('editing a field after verifying locks Continue again',
      (tester) async {
    await open(tester, SetupWizard(
      verifyCredentials: (u, k) async => '/UserPic/Player.png',
    ));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('setup-username')), 'player');
    await tester.enterText(find.byKey(const Key('setup-apikey')), 'good');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isTrue);

    // Typing over a verified name must not carry the old confirmation
    // forward, otherwise the screen says "Signed in as <whatever is typed>"
    // and Continue stays unlocked for a pair that was never checked.
    await tester.enterText(find.byKey(const Key('setup-username')), 'typo');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isFalse);
    expect(find.textContaining('Signed in as'), findsNothing);
  });

  testWidgets('the re-lock survives leaving and returning to the step',
      (tester) async {
    await open(tester, SetupWizard(
      verifyCredentials: (u, k) async => '/UserPic/Player.png',
    ));
    await tester.pump();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('setup-username')), 'player');
    await tester.enterText(find.byKey(const Key('setup-apikey')), 'good');
    await tester.tap(find.text('VERIFY'));
    await tester.pumpAndSettle();

    // Dropping focus lets the PageView discard the step's state, so anything
    // the step remembered about being verified is gone on the way back.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    // Still verified: the text matches the pair that passed.
    expect(continueEnabled(tester), isTrue);
    expect(find.textContaining('Signed in as player'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('setup-username')), 'typo');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isFalse);
    expect(find.textContaining('Signed in as'), findsNothing);
  });

  testWidgets('correcting a console mapping persists an override',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('setup_wizard_test');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory(p.join(root.path, 'Mystery System')).createSync();

    // The step lists real directories, and dart:io futures only complete on the
    // real event loop; outside runAsync the folder walk never finishes. Poll
    // rather than sleeping a fixed span, which races a loaded CI box.
    await tester.runAsync(() async {
      await open(tester, SetupWizard(
        verifyCredentials: (u, k) async => '/UserPic/Player.png',
        initialFolder: root.path,
        initialStep: 2,
      ));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('Mystery System').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('folder row never appeared');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Mystery System'), findsOneWidget);

    // Pick an explicit console for the folder the name-matcher can't place.
    await tester.tap(find.byKey(const Key('console-Mystery System')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Game Boy').last);
    await tester.pumpAndSettle();

    final overrides = await ScanSettings.folderConsoleOverrides();
    expect(overrides['Mystery System'], 4); // Game Boy
  });

  testWidgets('excluding a folder persists and can be undone', (tester) async {
    final root = Directory.systemTemp.createTempSync('setup_wizard_exclude');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory(p.join(root.path, 'BIOS')).createSync();

    await tester.runAsync(() async {
      await open(tester, SetupWizard(
        verifyCredentials: (u, k) async => '/UserPic/Player.png',
        initialFolder: root.path,
        initialStep: 2,
      ));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('BIOS').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('folder row never appeared');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    // Ticked means "scan this folder", so a fresh folder starts checked.
    bool checked() => tester
        .widget<Checkbox>(find.byKey(const Key('exclude-BIOS')))
        .value!;
    expect(checked(), isTrue);

    await tester.tap(find.byKey(const Key('exclude-BIOS')));
    await tester.pumpAndSettle();

    expect(await ScanSettings.ignoredFolders(), ['BIOS']);
    expect(checked(), isFalse);
    // Still listed, so the exclusion is not a one-way door.
    expect(find.text('BIOS'), findsOneWidget);
    expect(find.text('Excluded, not scanned'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exclude-BIOS')));
    await tester.pumpAndSettle();

    expect(await ScanSettings.ignoredFolders(), isEmpty);
    expect(checked(), isTrue);
  });

  testWidgets('re-enabling a folder counts its ROMs again', (tester) async {
    final root = Directory.systemTemp.createTempSync('setup_wizard_recount');
    addTearDown(() => root.deleteSync(recursive: true));
    final system = Directory(p.join(root.path, 'Game Boy'))..createSync();
    File(p.join(system.path, 'demo.gb')).writeAsStringSync('x');

    await tester.runAsync(() async {
      await open(tester, SetupWizard(
        verifyCredentials: (u, k) async => '/UserPic/Player.png',
        initialFolder: root.path,
        initialStep: 2,
        importScrapedData: (r, paths) async =>
            const ImportResult([], 0, {}),
      ));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('1 ROM').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('initial count never landed');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('exclude-Game Boy')));
      await tester.pumpAndSettle();
      expect(find.text('Excluded, not scanned'), findsOneWidget);

      // Re-enabling must walk the folder again. Without that the row keeps the
      // cleared count and sits on "counting..." forever.
      await tester.tap(find.byKey(const Key('exclude-Game Boy')));
      final recount = DateTime.now().add(const Duration(seconds: 5));
      while (find.text('1 ROM').evaluate().isEmpty) {
        if (DateTime.now().isAfter(recount)) fail('count stuck after re-enable');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('1 ROM'), findsOneWidget);
    expect(find.text('counting…'), findsNothing);
  });

  testWidgets('scraped data beside the ROMs is imported during setup',
      (tester) async {
    final root = Directory.systemTemp.createTempSync('setup_wizard_scrape');
    addTearDown(() => root.deleteSync(recursive: true));
    final system = Directory(p.join(root.path, 'Game Boy'))..createSync();
    final rom = File(p.join(system.path, 'demo.gb'))..writeAsStringSync('x');
    File(p.join(system.path, 'gamelist.xml')).writeAsStringSync(
        '<gameList><game><path>./demo.gb</path>'
        '<name>Demo</name></game></gameList>');

    // The importer itself is covered by the gamelist_importer tests; what
    // matters here is that the wizard hands it the ROMs the walk actually
    // found, before any RA scan has run.
    String? seenRoot;
    Set<String>? seenPaths;
    Future<ImportResult> fakeImport(String r, Set<String> paths) async {
      seenRoot = r;
      seenPaths = paths;
      return ImportResult(
        const [ScrapedGame(romPath: 'demo.gb', title: 'Demo')],
        0,
        const {'Game Boy': 1},
      );
    }

    await tester.runAsync(() async {
      await open(tester, SetupWizard(
        verifyCredentials: (u, k) async => '/UserPic/Player.png',
        initialFolder: root.path,
        initialStep: 2,
        importScrapedData: fakeImport,
      ));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.textContaining('Found Skraper media').evaluate().isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('scraped summary never appeared');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();

    expect(seenRoot, root.path);
    expect(seenPaths, contains(rom.path));
    expect(
      find.textContaining('1 game across 1 system'),
      findsOneWidget,
    );
  });

  testWidgets('starting the first scan queues it for the home screen',
      (tester) async {
    firstScanRequest.value = false;
    addTearDown(() => firstScanRequest.value = false);

    await open(tester, const SetupWizard(initialStep: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('START SCAN'));
    await tester.pump();

    expect(firstScanRequest.value, isTrue);
  });

  testWidgets('choosing later finishes setup without queuing a scan',
      (tester) async {
    firstScanRequest.value = false;
    addTearDown(() => firstScanRequest.value = false);

    await open(tester, const SetupWizard(initialStep: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LATER'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(firstScanRequest.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefKeys.setupDone), isTrue);
  });

  testWidgets('finishing closes the modal back onto the page under it',
      (tester) async {
    addTearDown(() => firstScanRequest.value = false);

    await open(tester, const SetupWizard(initialStep: 4));
    await tester.pumpAndSettle();
    expect(find.text('Ready to scan'), findsOneWidget);

    await tester.tap(find.text('LATER'));
    await tester.pumpAndSettle();

    expect(find.byType(SetupWizard), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the step bar names every step', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    for (final name in ['WELCOME', 'ACCOUNT', 'LIBRARY', 'STYLE', 'SCAN']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('picking Kiosk on the style step saves the mode',
      (tester) async {
    addTearDown(() => appModeListenable.value = AppMode.cleaning);

    await open(tester, const SetupWizard(initialStep: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kiosk'));
    await tester.pumpAndSettle();

    expect(appModeListenable.value, AppMode.gaming);
  });

  testWidgets('the scan step swaps Continue for the scan choices',
      (tester) async {
    await open(tester, const SetupWizard(initialStep: 4));
    await tester.pumpAndSettle();

    // One set of actions, in the footer: no dead Continue beside them.
    expect(find.text('CONTINUE'), findsNothing);
    expect(find.text('START SCAN'), findsOneWidget);
    expect(find.text('LATER'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);
  });

  testWidgets('restore on the welcome step asks before replacing anything',
      (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('RESTORE FROM BACKUP'));
    await tester.pumpAndSettle();
    expect(find.text('Restore from backup?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Restore from backup?'), findsNothing);
    expect(find.byType(SetupWizard), findsOneWidget);
  });

  testWidgets('tapping outside does not dismiss it', (tester) async {
    await open(tester);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(SetupWizard), findsOneWidget);
  });
}
