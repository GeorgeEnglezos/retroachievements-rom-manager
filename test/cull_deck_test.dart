import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/cull_deck_builder.dart';
import 'package:rarm/services/cull_store.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/screens/cull_deck.dart';
import 'package:rarm/widgets/cull_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

CullCardData _card(String name) {
  final rom = RomResult(filePath: 'snes/$name.sfc', fileName: '$name.sfc');
  return CullCardData(
      rom: rom, discs: [rom], memberKey: 'path:snes/$name.sfc');
}

CullCard _findCard(WidgetTester tester, CullCardData card) =>
    tester.widget<CullCard>(find.byWidgetPredicate(
        (w) => w is CullCard && w.card.memberKey == card.memberKey));

// The face-up card is the one inside the Dismissible; the peeking card behind
// it renders a second CullCard, so every top-card assertion scopes to this.
CullCardData _top(WidgetTester tester) => tester
    .widget<CullCard>(find.descendant(
        of: find.byType(Dismissible), matching: find.byType(CullCard)))
    .card;

Finder _topIcon(IconData icon) =>
    find.descendant(of: find.byType(Dismissible), matching: find.byIcon(icon));

bool _undoEnabled(WidgetTester tester) =>
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'UNDO'))
        .onPressed !=
    null;

// Keyed by console so pumping a second console's deck builds a fresh State
// instead of reusing the first one's.
Widget _deck(List<CullCardData> cards,
        {Set<String> decided = const {}, String console = 'SNES'}) =>
    MaterialApp(
      home: CullDeck(
        key: ValueKey(console),
        consoleName: console,
        allCards: cards,
        decided: decided,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const launcher = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CullStore().clear();
    PlaylistStore().clear();
    // The search button opens a browser; swallow the platform call so the tap
    // exercises the deck, not url_launcher.
    messenger.setMockMethodCallHandler(launcher, (call) async => true);
  });

  tearDown(() => messenger.setMockMethodCallHandler(launcher, null));

  group('verdicts', () {
    testWidgets('TRASH decides the top card, advances, and fills Trash',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'TRASH'));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, beta.memberKey);
      expect(find.text('SNES · 1 / 2'), findsOneWidget);
      expect(await CullStore().decided(), {alpha.memberKey});
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          {trashId});
    });

    testWidgets('KEEP decides the top card and advances without a playlist',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'KEEP'));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, beta.memberKey);
      expect(await CullStore().decided(), {alpha.memberKey});
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          isEmpty);
    });

    testWidgets('the favorite button decides, advances, and adds to Favorites',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, beta.memberKey);
      expect(await CullStore().decided(), {alpha.memberKey});
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          {favoritesId});
    });

    testWidgets('the favorite button reflects the top card membership',
        (tester) async {
      final alpha = _card('alpha');
      await PlaylistStore().addMember(favoritesId, alpha.memberKey);
      await tester.pumpWidget(_deck([alpha, _card('beta')]));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('the search button leaves the card in place', (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      await tester.tap(_topIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, alpha.memberKey);
      expect(await CullStore().decided(), isEmpty);
    });

    testWidgets('arrow left trashes and arrow right keeps', (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      final gamma = _card('gamma');
      await tester.pumpWidget(_deck([alpha, beta, gamma]));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_top(tester).memberKey, beta.memberKey);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_top(tester).memberKey, gamma.memberKey);

      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          {trashId});
      expect(await PlaylistStore().playlistsContaining(beta.memberKey),
          isEmpty);
    });
  });

  group('undo', () {
    testWidgets('is disabled with nothing to undo', (tester) async {
      await tester.pumpWidget(_deck([_card('alpha')]));
      await tester.pump();

      expect(_undoEnabled(tester), false);
    });

    testWidgets('enables on the very first decision, not one card later',
        (tester) async {
      await tester.pumpWidget(_deck([_card('alpha'), _card('beta')]));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'KEEP'));
      await tester.pump();

      expect(_undoEnabled(tester), true);
    });

    testWidgets('restores the last card and its playlist membership',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'TRASH'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'UNDO'));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, alpha.memberKey);
      expect(find.text('SNES · 0 / 2'), findsOneWidget);
      expect(await CullStore().decided(), isEmpty);
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          isEmpty);
      expect(_undoEnabled(tester), false);
    });

    testWidgets('leaves a Trash membership that predates the run',
        (tester) async {
      final alpha = _card('alpha');
      // Trashed by hand before the deck ever opened.
      await PlaylistStore().addMember(trashId, alpha.memberKey);
      await tester.pumpWidget(_deck([alpha, _card('beta')]));
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'TRASH'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'UNDO'));
      await tester.pumpAndSettle();

      expect(await CullStore().decided(), isEmpty);
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          {trashId});
    });

    testWidgets("cannot reach a verdict made in another deck's run",
        (tester) async {
      final alpha = _card('alpha');
      await tester.pumpWidget(_deck([alpha, _card('beta')]));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'TRASH'));
      await tester.pumpAndSettle();

      // A second console's deck: its own history is empty, so undo must stay
      // dead rather than popping the first deck's verdict.
      await tester.pumpWidget(_deck([_card('gamma')], console: 'NES'));
      await tester.pumpAndSettle();

      expect(_undoEnabled(tester), false);
      expect(await CullStore().decided(), {alpha.memberKey});
      expect(await PlaylistStore().playlistsContaining(alpha.memberKey),
          {trashId});
    });
  });

  group('start over', () {
    testWidgets('confirmed, it restores the full deck', (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'KEEP'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.replay));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Start over'));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, alpha.memberKey);
      expect(find.text('SNES · 0 / 2'), findsOneWidget);
      expect(await CullStore().decided(), isEmpty);
      expect(_undoEnabled(tester), false);
    });

    testWidgets('cancelled, it changes nothing', (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'KEEP'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.replay));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(_top(tester).memberKey, beta.memberKey);
      expect(await CullStore().decided(), {alpha.memberKey});
    });
  });

  group('deleted roms', () {
    testWidgets(
        'a ROM deleted from the dialog drops out of the deck without recording a verdict',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      expect(find.text('alpha.sfc'), findsOneWidget);

      _findCard(tester, alpha).onDeleted!();
      await tester.pump();

      expect(find.text('alpha.sfc'), findsNothing);
      expect(_top(tester).memberKey, beta.memberKey);
      expect(await CullStore().decided(), isEmpty);
    });

    testWidgets('a repeat delete for the same card leaves the next one alone',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      // The detail dialog fires onDeleted once per disc and stays open for the
      // rest, so the same callback can arrive twice for one card.
      final drop = _findCard(tester, alpha).onDeleted!;
      drop();
      await tester.pump();
      drop();
      await tester.pump();

      expect(_top(tester).memberKey, beta.memberKey);
    });

    testWidgets('a deleted ROM leaves the total and is not resurrected',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      _findCard(tester, alpha).onDeleted!();
      await tester.pump();

      // It never counted as decided, so the total drops instead.
      expect(find.text('SNES · 0 / 1'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.replay));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Start over'));
      await tester.pumpAndSettle();

      expect(find.text('alpha.sfc'), findsNothing);
      expect(find.text('SNES · 0 / 1'), findsOneWidget);
    });

    testWidgets('the peeking background card has no onDeleted wired',
        (tester) async {
      final alpha = _card('alpha');
      final beta = _card('beta');
      await tester.pumpWidget(_deck([alpha, beta]));
      await tester.pump();

      expect(_findCard(tester, beta).onDeleted, isNull);
    });
  });

  group('finished console', () {
    testWidgets('offers the next console as the main action', (tester) async {
      final alpha = _card('alpha');
      var jumped = false;
      await tester.pumpWidget(MaterialApp(
        home: CullDeck(
          consoleName: 'SNES',
          allCards: [alpha],
          decided: {alpha.memberKey},
          nextConsoleName: 'NES',
          onNextConsole: () => jumped = true,
        ),
      ));
      await tester.pump();

      expect(find.text('All SNES games decided.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Next: NES'));
      expect(jumped, isTrue);
    });

    testWidgets('says every console is done when there is no next one',
        (tester) async {
      final alpha = _card('alpha');
      await tester.pumpWidget(_deck([alpha], decided: {alpha.memberKey}));
      await tester.pump();

      expect(find.text('Every console is done.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.widgetWithText(TextButton, 'Start over'), findsOneWidget);
    });
  });

  testWidgets('cards already decided when the deck opens never show up',
      (tester) async {
    final alpha = _card('alpha');
    final beta = _card('beta');
    await tester.pumpWidget(_deck([alpha, beta], decided: {alpha.memberKey}));
    await tester.pump();

    expect(_top(tester).memberKey, beta.memberKey);
    expect(find.text('SNES · 1 / 2'), findsOneWidget);
  });
}
