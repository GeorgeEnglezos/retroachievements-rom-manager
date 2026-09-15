import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/ui_scale.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';
import 'package:rarm/widgets/ui_scale_control.dart';

Widget _host() => MaterialApp(
      theme: uiTheme(UiTokens.dark),
      home: const Scaffold(body: Center(child: UiScaleControl())),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uiScaleListenable.value = 1.0;
  });

  testWidgets('shows the current scale and steps up on plus', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(uiScaleListenable.value, greaterThan(1.0));
    expect(find.text(uiScaleLabel(uiScaleSteps[3])), findsOneWidget);
  });

  testWidgets('plus is disabled at the maximum', (tester) async {
    uiScaleListenable.value = uiScaleSteps.last;
    await tester.pumpWidget(_host());

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Still at max: the disabled button did nothing.
    expect(uiScaleListenable.value, uiScaleSteps.last);
  });
}
