import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/disc_formats.dart';

void main() {
  group('DiscFormats', () {
    test('compressed disc formats need decompression', () {
      expect(DiscFormats.needsDecompression('game.rvz'), isTrue);
      expect(DiscFormats.needsDecompression('D:/roms/gc/Gizmo.RVZ'), isTrue);
      expect(DiscFormats.needsDecompression('game.wbfs'), isTrue);
      expect(DiscFormats.needsDecompression('game.wia'), isTrue);
      expect(DiscFormats.needsDecompression('game.gcz'), isTrue);
      expect(DiscFormats.needsDecompression('game.ciso'), isTrue);
    });

    test('raw disc formats do not need decompression', () {
      expect(DiscFormats.needsDecompression('game.iso'), isFalse);
      expect(DiscFormats.needsDecompression('game.gcm'), isFalse);
      expect(DiscFormats.needsDecompression('game.gba'), isFalse);
    });

    test('NKit images are detected but NOT routed to decompression', () {
      // DolphinTool can't rebuild NKit (output stays NKit, same hash, RA
      // GameID 0), so NKit must not go through the decompression path.
      expect(DiscFormats.isNkit('Blahblah Galaxy.nkit.iso'), isTrue);
      expect(DiscFormats.isNkit('D:/roms/wii/Space Hunter.NKIT.ISO'), isTrue);
      expect(DiscFormats.isNkit('game.nkit.gcm'), isTrue);
      expect(DiscFormats.isNkit('game.iso'), isFalse);
      expect(DiscFormats.needsDecompression('Blahblah Galaxy.nkit.iso'),
          isFalse);
      expect(DiscFormats.needsDecompression('game.nkit.gcm'), isFalse);
    });
  });
}
