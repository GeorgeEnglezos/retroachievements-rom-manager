import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/ui/ui_card.dart';
import 'package:rarm/widgets/ui/ui_focusable.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: uiTheme(UiTokens.dark), home: Scaffold(body: child));

void main() {
  // Regression: the card rounds its corners through the decoration, but most
  // callers pass padding: zero and a child that paints edge to edge (box art,
  // the storage size bar, a group stripe). Container does NOT clip to its own
  // borderRadius by default, so a rounded-but-unclipped card renders square
  // corners on top of the rounded edge. Rounded and clipped are one contract
  // here; asserting either alone would let the bug back in.
  testWidgets('rounds AND clips, so a full-bleed child cannot square the corners',
      (tester) async {
    await tester.pumpWidget(_host(
      const UiCard(
        padding: EdgeInsets.zero,
        child: SizedBox(width: 200, height: 60, child: ColoredBox(color: Colors.purple)),
      ),
    ));

    final card = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(UiCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(card.clipBehavior, isNot(Clip.none));
    expect((card.decoration as BoxDecoration).borderRadius, isNotNull);
  });

  testWidgets('onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(
      UiCard(onTap: () => tapped = true, child: const Text('row')),
    ));
    await tester.tap(find.text('row'));
    expect(tapped, isTrue);
  });

  testWidgets('tappable card fills tight parent constraints', (tester) async {
    await tester.pumpWidget(_host(
      SizedBox(
        width: 250,
        height: 180,
        child: UiCard(
          onTap: () {},
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Icon(Icons.star, size: 24)],
          ),
        ),
      ),
    ));

    final card = tester.renderObject<RenderBox>(find.descendant(
      of: find.byType(UiCard),
      matching: find.byType(AnimatedContainer),
    ));
    expect(card.size.width, 250);
    expect(card.size.height, 180);
  });

  testWidgets('showShadow:false reaches the UiFocusable shell', (
    tester,
  ) async {
    await tester.pumpWidget(_host(
      UiCard(onTap: () {}, showShadow: false, child: const Text('row')),
    ));
    final focusable = tester.widget<UiFocusable>(find.byType(UiFocusable));
    expect(focusable.showShadow, isFalse);
  });
}
