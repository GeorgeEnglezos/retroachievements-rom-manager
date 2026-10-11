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
  
    test('compression advice: target per system, candidates, estimate', () {
      // CD/DVD systems go to CHD, GameCube/Wii to RVZ; cartridges get none.
      expect(DiscFormats.compressTargetFor(12), DiscTarget.chd);
      expect(DiscFormats.compressTargetFor(16), DiscTarget.rvz);
      expect(DiscFormats.compressTargetFor(19), DiscTarget.rvz);
      expect(DiscFormats.compressTargetFor(7), isNull);
      expect(DiscFormats.compressTargetFor(null), isNull);

      final cd = [
        'Zorblax Quest (Disc 1).bin', 'Zorblax Quest (Disc 1).cue',
        'Moon Diver X.iso', 'Pixel Rally.gdi', 'Old Dump.img',
        'Already Small.chd', 'notes.txt',
      ].where((f) => DiscFormats.isUncompressedDisc(f, DiscTarget.chd));
      expect(cd.length, 5);

      final gc = [
        'Blorp Party.iso', 'Blorp Party 2.gcm', 'Sky Kart.wbfs',
        'Done Already.rvz', 'Stripped.nkit.iso',
      ].where((f) => DiscFormats.isUncompressedDisc(f, DiscTarget.rvz));
      expect(gc, ['Blorp Party.iso', 'Blorp Party 2.gcm', 'Sky Kart.wbfs']);

      // The estimate is a fraction of the input, never more than it.
      for (final t in DiscTarget.values) {
        final saved = t.estimatedSaving(1000);
        expect(saved, greaterThan(0));
        expect(saved, lessThan(1000));
      }
      expect(DiscTarget.chd.estimatedSaving(0), 0);
    });
  });
}
