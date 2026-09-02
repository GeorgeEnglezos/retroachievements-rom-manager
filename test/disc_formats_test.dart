import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/disc_formats.dart';

void main() {
  group('DiscFormats', () {
    test('on-device vs DolphinTool routing per format', () {
      // Always on-device, never DolphinTool.
      for (final ext in ['ciso', 'wbfs', 'gcz']) {
        expect(DiscFormats.hasOnDeviceReader('game.$ext'), isTrue, reason: ext);
        expect(DiscFormats.requiresDolphinTool('game.$ext'), isFalse,
            reason: ext);
      }
      // RVZ: on-device attempt (GameCube) with DolphinTool fallback (Wii), so
      // it's never in the never-hashable set.
      expect(DiscFormats.hasOnDeviceReader('game.rvz'), isTrue);
      expect(DiscFormats.needsDolphinTool('game.rvz'), isTrue);
      expect(DiscFormats.requiresDolphinTool('game.rvz'), isFalse);
      // WIA: no on-device reader, so it truly requires DolphinTool.
      expect(DiscFormats.hasOnDeviceReader('game.wia'), isFalse);
      expect(DiscFormats.requiresDolphinTool('game.wia'), isTrue);

      expect(DiscFormats.hasOnDeviceReader('game.iso'), isFalse);
    });

    test('NKit images are detected (hash_service short-circuits them)', () {
      // DolphinTool can't rebuild NKit (output stays NKit, same hash, RA
      // GameID 0), so hash_service flags NKit unsupported before format routing.
      expect(DiscFormats.isNkit('Blahblah Galaxy.nkit.iso'), isTrue);
      expect(DiscFormats.isNkit('D:/roms/wii/Space Hunter.NKIT.ISO'), isTrue);
      expect(DiscFormats.isNkit('game.nkit.gcm'), isTrue);
      expect(DiscFormats.isNkit('game.iso'), isFalse);
    });
  });
}
