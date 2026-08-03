import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/disc_grouping.dart';

RomResult _rom(String path) {
  final name = path.split('/').last;
  return RomResult(filePath: path, fileName: name);
}

void main() {
  group('discNumber', () {
    test('parses Redump/No-Intro disc tokens', () {
      expect(discNumber('Quest (Disc 1).chd'), 1);
      expect(discNumber('Quest (Disc 2 of 3).chd'), 2);
      expect(discNumber('Game [Disk 3].iso'), 3);
      expect(discNumber('Game (CD1).bin'), 1);
      expect(discNumber('Game (CD-2).bin'), 2);
    });

    test('returns null when there is no disc token', () {
      expect(discNumber('Quest Chronicles (USA).chd'), isNull);
      expect(discNumber('Disco Volante (USA).iso'), isNull); // "disc" + letter
    });
  });

  test('stripDiscToken removes only the disc token', () {
    expect(stripDiscToken('Quest Chronicles (USA) (Disc 1).chd'),
        'Quest Chronicles (USA).chd');
  });

  group('groupDiscs', () {
    test('collapses sibling discs into one multi-disc group, sorted', () {
      final roms = [
        _rom('psx/Quest (USA) (Disc 2).chd'),
        _rom('psx/Quest (USA) (Disc 1).chd'),
        _rom('psx/Quest (USA) (Disc 3).chd'),
      ];
      final groups = groupDiscs(roms);
      expect(groups.length, 1);
      expect(groups.single.isMultiDisc, true);
      expect(groups.single.discs.map((r) => discNumber(r.fileName)),
          [1, 2, 3]);
    });

    test('a lone disc with no sibling stays a singleton', () {
      final groups = groupDiscs([_rom('psx/Quest (USA) (Disc 1).chd')]);
      expect(groups.single.isMultiDisc, false);
    });

    test('different base names do not group', () {
      final groups = groupDiscs([
        _rom('psx/Quest (Disc 1).chd'),
        _rom('psx/Legend (Disc 1).chd'),
      ]);
      expect(groups.length, 2);
      expect(groups.every((g) => !g.isMultiDisc), true);
    });

    test('same name in different folders do not group', () {
      final groups = groupDiscs([
        _rom('a/Quest (Disc 1).chd'),
        _rom('b/Quest (Disc 2).chd'),
      ]);
      expect(groups.length, 2);
    });

    test('preserves input order, group at its first disc position', () {
      final roms = [
        _rom('psx/Alpha.chd'),
        _rom('psx/Quest (Disc 1).chd'),
        _rom('psx/Zeta.chd'),
        _rom('psx/Quest (Disc 2).chd'),
      ];
      final groups = groupDiscs(roms);
      // Alpha, [Quest group], Zeta: the group takes disc 1's slot.
      expect(groups.length, 3);
      expect(groups[0].discs.single.fileName, 'Alpha.chd');
      expect(groups[1].isMultiDisc, true);
      expect(groups[2].discs.single.fileName, 'Zeta.chd');
    });

    test('representative prefers a matched disc', () {
      final d1 = _rom('psx/Quest (Disc 1).chd')..status = RomStatus.notFetched;
      final d2 = _rom('psx/Quest (Disc 2).chd')..status = RomStatus.supported;
      final g = groupDiscs([d1, d2]).single;
      expect(g.representative, d2);
    });
  });
}
