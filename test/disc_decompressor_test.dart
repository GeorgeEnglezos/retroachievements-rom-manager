@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/disc_decompressor.dart';

void main() {
  group('DiscDecompressor.toolPathNextTo', () {
    test('derives DolphinTool path from a Dolphin.exe path', () {
      expect(
        DiscDecompressor.toolPathNextTo(r'C:\Emu\Dolphin\Dolphin.exe'),
        r'C:\Emu\Dolphin\DolphinTool.exe',
      );
    });

    test('returns null for a non-dolphin exe', () {
      expect(
        DiscDecompressor.toolPathNextTo(r'C:\Emu\retroarch\retroarch.exe'),
        isNull,
      );
    });
  });
}
