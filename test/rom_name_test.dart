import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/rom_name.dart';

void main() {
  test('bareExtension lowercases and drops the dot', () {
    expect(bareExtension('a/Game.ISO'), 'iso');
    expect(bareExtension('Game.nkit.iso'), 'iso');
    expect(bareExtension('noext'), '');
  });

  group('cleanRomName', () {
    test('drops the extension', () {
      expect(cleanRomName('Some Game.iso'), 'Some Game');
    });
    test('strips parenthesised and bracketed tags', () {
      expect(cleanRomName('Some Game (USA) (Rev 1) [!].bin'), 'Some Game');
    });
    test('collapses underscores and stray dots to spaces', () {
      expect(cleanRomName('Some_Game.Title.chd'), 'Some Game Title');
    });
    test('trims a disc suffix', () {
      expect(cleanRomName('Some Game (Disc 1).chd'), 'Some Game');
    });
    test('collapses repeated whitespace', () {
      expect(cleanRomName('Some   Game.iso'), 'Some Game');
    });
  });
}
