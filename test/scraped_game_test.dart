import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/scraped_game.dart';

void main() {
  test('round-trips through JSON', () {
    const g = ScrapedGame(
      romPath: r'C:\roms\ps3\Racer.iso',
      title: 'Racer',
      publisher: 'Acme',
      genre: 'Racing',
      releaseDate: '1996-01-01',
      images: {'boxart': r'C:\roms\ps3\media\box\Racer.png'},
    );
    final back = ScrapedGame.fromJson(g.toJson());
    expect(back.romPath, g.romPath);
    expect(back.title, 'Racer');
    expect(back.publisher, 'Acme');
    expect(back.images['boxart'], r'C:\roms\ps3\media\box\Racer.png');
  });

  group('thumbPath', () {
    test('prefers support over boxart', () {
      const g = ScrapedGame(romPath: '/a', title: 'T', images: {
        'boxart': '/m/images/a.png',
        'support': '/m/support/a.png',
      });
      expect(g.thumbPath, '/m/support/a.png');
    });

    test('falls back to boxart, then any other image, never video', () {
      const boxOnly = ScrapedGame(
          romPath: '/a', title: 'T', images: {'boxart': '/m/images/a.png'});
      expect(boxOnly.thumbPath, '/m/images/a.png');

      const other = ScrapedGame(romPath: '/a', title: 'T', images: {
        'video': '/m/videos/a.mp4',
        'screenshot': '/m/ss/a.png',
      });
      expect(other.thumbPath, '/m/ss/a.png');

      const videoOnly = ScrapedGame(
          romPath: '/a', title: 'T', images: {'video': '/m/videos/a.mp4'});
      expect(videoOnly.thumbPath, isNull);
    });
  });

  test('missing optional fields decode to null / empty', () {
    final g = ScrapedGame.fromJson({'romPath': '/a', 'title': 'T'});
    expect(g.publisher, isNull);
    expect(g.images, isEmpty);
  });
}
