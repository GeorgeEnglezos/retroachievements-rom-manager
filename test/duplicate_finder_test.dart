import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/duplicate_finder.dart';

void main() {
  group('normalizeGameName', () {
    test('strips extension and region tag', () {
      expect(normalizeGameName('Racer (USA).md'), normalizeGameName('Racer (Europe).bin'));
    });
    test('ignores word order and articles position', () {
      expect(
        normalizeGameName('Legend of Sword, The (USA).sfc'),
        normalizeGameName('The Legend of Sword (Europe).sfc'),
      );
    });
    test('chd and bin/cue of same disc match', () {
      expect(
        normalizeGameName('Quest Chronicles (USA) (Disc 1).chd'),
        normalizeGameName('Quest Chronicles (USA) (Disc 1).bin'),
      );
    });
    test('different discs do NOT match', () {
      expect(
        normalizeGameName('Quest Chronicles (USA) (Disc 1).chd'),
        isNot(normalizeGameName('Quest Chronicles (USA) (Disc 2).chd')),
      );
    });
    test('strips revision and bracket tags', () {
      expect(
        normalizeGameName('Combat (USA) (Rev 1) [!].nes'),
        normalizeGameName('Combat (USA).nes'),
      );
    });
    test('strips language list tag', () {
      expect(
        normalizeGameName('Fighter 3 (Europe) (En,Fr,De).bin'),
        normalizeGameName('Fighter 3 (USA).bin'),
      );
    });
  });

  group('assignDuplicateGroups', () {
    RomResult rom(String name, {int? gameId}) {
      final r = RomResult(filePath: name, fileName: name);
      r.gameId = gameId;
      return r;
    }

    test('groups same gameId', () {
      final roms = [rom('a.bin', gameId: 5), rom('b.chd', gameId: 5), rom('c.bin', gameId: 9)];
      assignDuplicateGroups(roms);
      expect(roms[0].duplicateGroupId, isNotNull);
      expect(roms[0].duplicateGroupId, roms[1].duplicateGroupId);
      expect(roms[2].duplicateGroupId, isNull);
    });

    test('groups by normalized name when gameId missing', () {
      final roms = [rom('Racer (USA).md'), rom('Racer (Europe).bin'), rom('Blahblah (USA).nes')];
      assignDuplicateGroups(roms);
      expect(roms[0].duplicateGroupId, isNotNull);
      expect(roms[0].duplicateGroupId, roms[1].duplicateGroupId);
      expect(roms[2].duplicateGroupId, isNull);
    });

    test('unions a matched and an unmatched copy by name', () {
      final roms = [rom('Racer (USA).md', gameId: 5), rom('Racer (Europe).bin')];
      assignDuplicateGroups(roms);
      expect(roms[0].duplicateGroupId, isNotNull);
      expect(roms[0].duplicateGroupId, roms[1].duplicateGroupId);
    });

    test('different discs stay separate', () {
      final roms = [
        rom('Quest (USA) (Disc 1).chd'),
        rom('Quest (USA) (Disc 2).chd'),
      ];
      assignDuplicateGroups(roms);
      expect(roms[0].duplicateGroupId, isNull);
      expect(roms[1].duplicateGroupId, isNull);
    });

    test('different discs of a matched game stay separate (shared gameId)', () {
      // Both discs of one game carry the same RA gameId; must not be flagged
      // as duplicates of each other.
      final roms = [
        rom('Quest (USA) (Disc 1).chd', gameId: 42),
        rom('Quest (USA) (Disc 2).chd', gameId: 42),
        rom('Quest (USA) (Disc 3).chd', gameId: 42),
      ];
      assignDuplicateGroups(roms);
      expect(roms.map((r) => r.duplicateGroupId), everyElement(isNull));
    });

    test('two copies of the same disc are still duplicates', () {
      final roms = [
        rom('a/Quest (USA) (Disc 1).chd', gameId: 42),
        rom('b/Quest (USA) (Disc 1).chd', gameId: 42),
        rom('a/Quest (USA) (Disc 2).chd', gameId: 42),
      ];
      assignDuplicateGroups(roms);
      // The two Disc 1 copies group; Disc 2 is alone.
      expect(roms[0].duplicateGroupId, isNotNull);
      expect(roms[0].duplicateGroupId, roms[1].duplicateGroupId);
      expect(roms[2].duplicateGroupId, isNull);
    });

    test('singletons stay null', () {
      final roms = [rom('Solo (USA).nes', gameId: 1)];
      assignDuplicateGroups(roms);
      expect(roms[0].duplicateGroupId, isNull);
    });
  });
}
