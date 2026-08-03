import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/theme/ui_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';

void main() {
  testWidgets('dark palette reaches the scheme and context.ui tokens',
      (tester) async {
    late UiTokens tokens;
    late Brightness brightness;
    await tester.pumpWidget(MaterialApp(
      theme: uiTheme(UiTokens.dark),
      home: Builder(builder: (context) {
        tokens = context.ui;
        brightness = Theme.of(context).colorScheme.brightness;
        return const SizedBox();
      }),
    ));

    expect(brightness, Brightness.dark);
    expect(tokens.background, UiTokens.dark.background);
  });

  test('light palette is the light theme and default fallback', () {
    expect(UiTokens.standard, UiTokens.light);
    expect(UiTokens.light.brightness, Brightness.light);
  });
}
