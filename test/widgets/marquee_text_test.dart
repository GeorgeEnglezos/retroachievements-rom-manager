import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/ui/marquee_text.dart';
import 'package:rarm/widgets/ui/ui_focusable.dart';

const _long = 'An Extremely Long Invented Title That Cannot Fit In The Tile';

Widget _host(String text) => MaterialApp(
  theme: uiTheme(UiTokens.light),
  home: Scaffold(
    body: Center(
      child: UiFocusable(
        borderRadius: BorderRadius.circular(8),
        onPressed: () {},
        child: SizedBox(width: 80, child: MarqueeText(text)),
      ),
    ),
  ),
);

double _dx(WidgetTester t) {
  final tr = find.descendant(
    of: find.byType(MarqueeText),
    matching: find.byType(Transform),
  );
  if (tr.evaluate().isEmpty) return 0;
  return t.widget<Transform>(tr).transform.getTranslation().x;
}

Future<TestGesture> _hover(WidgetTester t) async {
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(t.getCenter(find.byType(MarqueeText)));
  await t.pump();
  await t.pump(); // the ticker's first frame only marks its start
  return mouse;
}

void main() {
  // Hover highlights only show in the desktop (traditional) highlight mode.
  setUp(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional,
  );
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('a clipped title loops right to left while the tile is hovered, '
      'and snaps back to the ellipsis when the pointer leaves', (t) async {
    await t.pumpWidget(_host(_long));
    expect(t.widget<Text>(find.text(_long)).overflow, TextOverflow.ellipsis);

    final mouse = await _hover(t);
    await t.pump(const Duration(seconds: 1));
    expect(_dx(t), lessThan(0));
    // A trailing copy follows the title round, so the loop has no seam.
    expect(find.text(_long), findsNWidgets(2));

    await mouse.moveTo(const Offset(1, 1));
    await t.pump();
    expect(t.widget<Text>(find.text(_long)).overflow, TextOverflow.ellipsis);
    expect(_dx(t), 0);
    await t.pumpAndSettle();
  });

  testWidgets('a title that fits stays still on hover', (t) async {
    await t.pumpWidget(_host('Ab'));
    await _hover(t);
    await t.pump(const Duration(seconds: 3));
    expect(_dx(t), 0);
    await t.pumpAndSettle();
  });
}
