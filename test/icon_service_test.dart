import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rarm/services/icon_service.dart';

void main() {
  group('IconService.pngBytesToIco', () {
    test('converts a PNG to valid ICO bytes', () {
      final png = img.encodePng(img.Image(width: 8, height: 8));
      final ico = IconService.pngBytesToIco(png);
      expect(ico, isNotNull);
      // ICO magic: reserved(0) + type(1, icon). First 4 bytes = 00 00 01 00.
      expect(ico!.sublist(0, 4), [0, 0, 1, 0]);
    });

    test('returns null for non-image bytes', () {
      expect(IconService.pngBytesToIco([1, 2, 3, 4]), isNull);
    });
  });
}
