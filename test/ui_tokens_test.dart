import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/theme/ui_tokens.dart';

void main() {
  test('neither palette draws offset shadows', () {
    for (final ui in [UiTokens.light, UiTokens.dark]) {
      expect(ui.cardShadow, Offset.zero);
      expect(ui.controlShadow, Offset.zero);
      expect(ui.shadow(), isEmpty);
      expect(ui.shadow(ui.controlShadow), isEmpty);
    }
  });
}
