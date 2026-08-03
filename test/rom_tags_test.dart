import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_tags.dart';

List<String> labels(String name) => romTags(name).map((t) => t.label).toList();

void main() {
  group('romTags', () {
    test('plain release shows region and verified chips', () {
      expect(
        labels('Land Quest 4 (UE) [!].gba'),
        containsAll(['USA', 'EUR', 'GOOD']),
      );
      expect(
        labels('Kart Circuit (U) [!].gba'),
        containsAll(['USA', 'GOOD']),
      );
    });

    test('World region code (W) maps to WORLD', () {
      expect(labels('Block Stacker (W) [!].gb'), contains('WORLD'));
      expect(labels('Speed Runner (JW).md'), containsAll(['JPN', 'WORLD']));
    });

    test('hacks', () {
      expect(
        labels('Land Quest 4 (UE) [!] [Hack] [Parallel Mod v1.03].gba'),
        contains('HACK'),
      );
      expect(
        labels('Last Promise, The (V2.1) (Tactics Hack).gba'),
        contains('HACK'),
      );
      expect(
        labels('Creature Hunter by Cutlerine (Cartridge Hack) [a2].gba'),
        contains('HACK'),
      );
      // GoodTools single-letter hack codes ([h], [h1], [hC]), no "hack" word.
      expect(labels('Jump Hero [h1].nes'), contains('HACK'));
      expect(labels('Sword Quest [h].nes'), contains('HACK'));
      expect(labels('Space Hunter [hIR00].nes'), contains('HACK'));
    });

    test('translations are labelled by language', () {
      expect(labels('Origin 1+2 (Japan) [T-Eng].gba'), contains('ENG'));
      expect(labels('Origin 3 (J) [T+Eng1.2].gba'), contains('ENG'));
      expect(
        labels(
          'Tactics Saga - Fuuin no Tsurugi (J) [T+Eng2.1_Dark Twilkitri].gba',
        ),
        contains('ENG'),
      );
      expect(
        labels('Holiday Trip (Japan) [En by magicalpatcher v1.0].gba'),
        contains('ENG'),
      );
      expect(
        labels('Hover Racer - Climax (Japan) (En) (1.0) (Normmatt).gba'),
        contains('ENG'),
      );
      expect(
        labels('Legend of Sword, The - The Tiny Cap (E) (M5) [T+Pol1.0].gba'),
        contains('POL'),
      );
    });

    test('homebrew / public domain', () {
      expect(
        labels('Mountain Classic (v1.0) (homebrew).gba'),
        contains('HOMEBREW'),
      );
      expect(labels('Mountain Classic ~HOMEBREW~.gba'), contains('HOMEBREW'));
      expect(labels('Snakes by Neal Hunt (PD).gba'), contains('HOMEBREW'));
      expect(labels('Totally Awesome (Jam Build).gba'), contains('HOMEBREW'));
    });

    test('RA subset and bonus', () {
      expect(
        labels(
          'Crystal Saga V Advance (U) [!] [Subset - Four Job Fiesta].gba',
        ),
        contains('SUBSET'),
      );
      expect(
        labels('Speed Battle (U) (M6) [!] [Bonus].gba'),
        contains('BONUS'),
      );
    });

    test('proto / beta / demo', () {
      expect(
        labels('Metal Trooper - Super Vehicle-001 (Prototype).gba'),
        contains('PROTO'),
      );
      expect(
        labels('Metal Trooper - Super Vehicle-001 ~PROTOTYPE~.gba'),
        contains('PROTO'),
      );
      expect(
        labels(
          'Advance Battles (USA) (Rev 1) (No Glitch Patch) (Beta) (Bartis1989).gba',
        ),
        contains('BETA'),
      );
      expect(labels('Kart Racer XXL (Europe) (Demo).gba'), contains('DEMO'));
    });

    test('bad dump, sram, unlicensed', () {
      expect(labels('Dungeon - The Enemy (U) [b1].gba'), contains('BAD DUMP'));
      expect(
        labels(
          'Dream Heroes - The Legendary Star Medal (Japan) (En) (v1.1.8) (SRAM) (KMCTT).gba',
        ),
        contains('SRAM'),
      );
      expect(labels('Dash Advance IV (USA) (Unl).gba'), contains('UNL'));
    });

    test('GoodTools quality, modification, and release chips', () {
      expect(
        labels('Example (U) [o1] [c] [f2] [p] [t1] [x] [a2].gba'),
        containsAll([
          'OVERDUMP',
          'CHECKSUM',
          'FIXED',
          'PIRATE',
          'TRAINER',
          'BAD SUM',
          'ALT',
        ]),
      );
    });

    test('No-Intro language chips from multi-language tokens', () {
      expect(
        labels('Drill Machine (Europe) (En,Fr,De,Es,It).gba'),
        containsAll(['EUR', 'ENG', 'FRE', 'GER', 'SPA', 'ITA']),
      );
    });
  });

  group('romRegions', () {
    test('full names and letter codes', () {
      expect(romRegions('Drill Machine (U) [!].gba'), {'USA'});
      expect(romRegions('Invaders - Evolution Continues (UE) [!].gba'), {
        'USA',
        'Europe',
      });
      expect(romRegions('Origin 3 (J) [T+Eng1.2].gba'), {'Japan'});
      expect(
        romRegions('Metal Trooper - Super Vehicle-001 (Prototype).gba'),
        isEmpty,
      );
    });

    test('No-Intro multi-region token', () {
      expect(
        romRegions(
          'Tactics Saga - The Sacred Stones (USA, Australia) [Hack][Bandit Emblem 1.0].gba',
        ),
        {'USA', 'Australia'},
      );
      expect(romRegions('Drill Machine (Europe) (En,Fr,De,Es,It).gba'), {
        'Europe',
      });
    });

    test('a title word never mis-reads as a region', () {
      expect(romRegions('Bugs - World Party (U) (M5).gba'), {'USA'});
    });
  });
}
