import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';

void main() {
  group('RomResult', () {
    test('status defaults to notFetched', () {
      final r = RomResult(filePath: '/x/a.nes', fileName: 'a.nes');
      expect(r.status, RomStatus.notFetched);
    });

    test('thumbArt/boxArt read the RA icon and box art', () {
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
