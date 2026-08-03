import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/console_image.dart';

void main() {
  group('ConsoleImage.assetFor', () {
    test('known id maps to asset path', () {
      expect(ConsoleImage.assetFor(12), 'assets/consoles/12.png');
      expect(ConsoleImage.assetFor(3), 'assets/consoles/3.png');
    });
    test('null id returns null', () {
      expect(ConsoleImage.assetFor(null), isNull);
    });
    test('negative (display-only) ids map to the unsupported folder', () {
      expect(ConsoleImage.assetFor(-1), 'assets/consoles/unsupported/switch.png');
      expect(ConsoleImage.assetFor(-6), 'assets/consoles/unsupported/xbox.png');
    });
  });
}
