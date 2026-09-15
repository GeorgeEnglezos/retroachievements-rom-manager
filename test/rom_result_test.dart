import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';

void main() {
  group('RomResult', () {
    test('status defaults to notFetched', () {
      final r = RomResult(filePath: '/x/a.nes', fileName: 'a.nes');
      expect(r.status, RomStatus.notFetched);
    });

    test('thumbArt/boxArt prefer a third-party imageUrl over RA paths', () {
      final r = RomResult(filePath: 'ps3/x.iso', fileName: 'x.iso')
        ..imageIcon = '/Images/icon.png'
        ..imageBoxArt = '/Images/box.png'
        ..imageUrl = 'https://cdn/cover.png';
      expect(r.thumbArt, 'https://cdn/cover.png');
      expect(r.boxArt, 'https://cdn/cover.png');
    });

    test('thumbArt/boxArt fall back to RA paths when no imageUrl', () {
      final r = RomResult(filePath: 'snes/x.sfc', fileName: 'x.sfc')
        ..imageIcon = '/Images/icon.png'
        ..imageBoxArt = '/Images/box.png';
      expect(r.thumbArt, '/Images/icon.png');
      expect(r.boxArt, '/Images/box.png');
    });

    test('heroArt prefers an in-game screenshot over the title screen and box art',
        () {
      final r = RomResult(filePath: 'snes/x.sfc', fileName: 'x.sfc')
        ..imageBoxArt = '/Images/box.png'
        ..imageTitle = '/Images/title.png'
        ..imageIngame = '/Images/ingame.png';
      expect(r.heroArt, '/Images/ingame.png');
    });

    test('heroArt falls back to the title screen, then box art', () {
      final r = RomResult(filePath: 'snes/x.sfc', fileName: 'x.sfc')
        ..imageBoxArt = '/Images/box.png'
        ..imageTitle = '/Images/title.png';
      expect(r.heroArt, '/Images/title.png');

      r.imageTitle = null;
      expect(r.heroArt, '/Images/box.png');
    });
  });
}
