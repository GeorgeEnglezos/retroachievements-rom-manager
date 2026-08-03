import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/console_map.dart';

void main() {
  group('ConsoleMap.idForFolder', () {
    test('disc systems', () {
      expect(ConsoleMap.idForFolder('PSP'), 41);
      expect(ConsoleMap.idForFolder('Sony PlayStation Portable'), 41);
      expect(ConsoleMap.idForFolder('PS2 Games'), 21);
      expect(ConsoleMap.idForFolder('PSX'), 12);
      expect(ConsoleMap.idForFolder('Sony PlayStation'), 12);
      expect(ConsoleMap.idForFolder('Sega Saturn'), 39);
      expect(ConsoleMap.idForFolder('Dreamcast'), 40);
      expect(ConsoleMap.idForFolder('Sega CD'), 9);
    });

    test('alias precedence (specific beats generic)', () {
      expect(ConsoleMap.idForFolder('GBA'), 5);
      expect(ConsoleMap.idForFolder('GBC'), 6);
      expect(ConsoleMap.idForFolder('GB'), 4);
      expect(ConsoleMap.idForFolder('PS2'), 21); // not PlayStation (12)
      expect(ConsoleMap.idForFolder('PC Engine CD'), 76); // not PC Engine (8)
      expect(ConsoleMap.idForFolder('CPS1'), 27); // Arcade, not PlayStation (12)
      expect(ConsoleMap.idForFolder('CPS2'), 27); // Arcade, not PS2 (21)
      expect(ConsoleMap.idForFolder('CPS3'), 27); // Arcade
    });

    test('case-insensitive and path basename', () {
      expect(ConsoleMap.idForFolder(r'C:\roms\snes'), 3);
      expect(ConsoleMap.idForFolder('NiNtEnDo 64'), 2);
    });

    test('unknown folders return null', () {
      expect(ConsoleMap.idForFolder('BIOS'), isNull);
      expect(ConsoleMap.idForFolder('Saves'), isNull);
      expect(ConsoleMap.idForFolder('random stuff'), isNull);
    });
  });

  group('ConsoleMap.manufacturerForId', () {
    test('null and unknown return Other', () {
      expect(ConsoleMap.manufacturerForId(null), 'Other');
      expect(ConsoleMap.manufacturerForId(999), 'Other');
    });
  });

  group('DSi and Pokémon Mini', () {
    test('DSi folder resolves to the DSi console id', () {
      expect(ConsoleMap.idForFolder('dsi'), 78);
      expect(ConsoleMap.idForFolder('Nintendo DSi'), 78);
      expect(ConsoleMap.consoleNames[78], 'Nintendo DSi');
      expect(ConsoleMap.manufacturerForId(78), 'Nintendo');
    });

    test('Pokémon Mini folder still resolves to id 24', () {
      expect(ConsoleMap.idForFolder('pokemonmini'), 24);
    });
  });

  group('newly-wired hashable systems (icons already shipped)', () {
    test('resolve from folder names', () {
      expect(ConsoleMap.idForFolder('SG-1000'), 33);
      expect(ConsoleMap.idForFolder('ColecoVision'), 44);
      expect(ConsoleMap.idForFolder('Intellivision'), 45);
      expect(ConsoleMap.idForFolder('Vectrex'), 46);
      expect(ConsoleMap.idForFolder('PC-FX'), 49);
      expect(ConsoleMap.idForFolder('Neo Geo CD'), 56);
      expect(ConsoleMap.idForFolder('Fairchild Channel F'), 57);
      expect(ConsoleMap.idForFolder('Nintendo 3DS'), 62);
      expect(ConsoleMap.idForFolder('Atari Jaguar CD'), 77);
      expect(ConsoleMap.idForFolder('Famicom Disk System'), 81);
    });

    test('are RA-hashable and named', () {
      for (final id in [33, 44, 45, 46, 49, 56, 57, 62, 77, 81]) {
        expect(ConsoleMap.isRaSupported(id), isTrue, reason: 'id $id');
        expect(ConsoleMap.nameFor(id), isNotNull, reason: 'id $id');
      }
    });

    test('ordering: specific CD/disk beats the base cart system', () {
      expect(ConsoleMap.idForFolder('Jaguar CD'), 77); // not Jaguar (17)
      expect(ConsoleMap.idForFolder('Famicom Disk'), 81); // not Famicom/NES (7)
    });
  });

  group('non-RA display-only systems (negative ids)', () {
    test('resolve from folder names', () {
      expect(ConsoleMap.idForFolder('Nintendo Switch'), -1);
      expect(ConsoleMap.idForFolder('Switch'), -1);
      expect(ConsoleMap.idForFolder('Wii U'), -2);
      expect(ConsoleMap.idForFolder('WiiU'), -2);
      expect(ConsoleMap.idForFolder('PS3'), -3);
      expect(ConsoleMap.idForFolder('PlayStation 3'), -3);
      expect(ConsoleMap.idForFolder('PS4'), -4);
      expect(ConsoleMap.idForFolder('PS Vita'), -5);
      expect(ConsoleMap.idForFolder('Xbox'), -6);
      expect(ConsoleMap.idForFolder('Xbox 360'), -7);
    });

    test('ordering: Wii U beats Wii, Xbox 360 beats Xbox', () {
      expect(ConsoleMap.idForFolder('Wii U'), -2); // not Wii (19)
      expect(ConsoleMap.idForFolder('Xbox 360'), -7); // not Xbox (-6)
    });

    test('are named but NOT RA-supported', () {
      for (final id in [-1, -2, -3, -4, -5, -6, -7]) {
        expect(ConsoleMap.nameFor(id), isNotNull, reason: 'id $id');
        expect(ConsoleMap.isRaSupported(id), isFalse, reason: 'id $id');
      }
    });
  });

  group('ConsoleMap.isRaSupported / nameFor', () {
    test('hashable ids are supported', () {
      expect(ConsoleMap.isRaSupported(12), isTrue);
      expect(ConsoleMap.nameFor(12), 'PlayStation');
    });
    test('null and unknown ids are unsupported', () {
      expect(ConsoleMap.isRaSupported(null), isFalse);
      expect(ConsoleMap.isRaSupported(999), isFalse);
      expect(ConsoleMap.nameFor(null), isNull);
      expect(ConsoleMap.nameFor(999), isNull);
    });
  });

  group('ConsoleMap.manufacturerSortKey', () {
    test('Nintendo sorts before Sega', () {
      expect(ConsoleMap.manufacturerSortKey(7),
          lessThan(ConsoleMap.manufacturerSortKey(1)));
    });

    test('Sega sorts before Sony', () {
      expect(ConsoleMap.manufacturerSortKey(1),
          lessThan(ConsoleMap.manufacturerSortKey(12)));
    });

    test('unknown sorts last', () {
      final last = ConsoleMap.manufacturerSortKey(null);
      expect(ConsoleMap.manufacturerSortKey(7), lessThan(last));
      expect(ConsoleMap.manufacturerSortKey(1), lessThan(last));
      expect(ConsoleMap.manufacturerSortKey(12), lessThan(last));
    });
  });
}
