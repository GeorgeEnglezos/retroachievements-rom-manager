import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/scraper/dat_parser.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('dat'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String rel, String content) {
    final f = File(p.join(dir.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('parses game text, resolves rom path, finds convention media', () {
    write('media/images/Racer [X].png', 'x'); // boxart, exists
    write('media/support/Racer [X].png', 'x'); // support, exists
    // no screenshot file on disk -> not included
    final dat = write('Sys.dat', '''
<?xml version="1.0" encoding="utf-8"?>
<datafile>
  <header><name>Test</name></header>
  <game name="Racer &amp; Co">
    <description>Fast</description>
    <year>2011</year>
    <manufacturer>Acme</manufacturer>
    <rom name="Racer [X].7z" size="10" />
  </game>
</datafile>''');

    final games = parseDat(dat);
    expect(games, hasLength(1));
    final g = games.single;
    expect(g.title, 'Racer & Co'); // XML entity decoded
    expect(g.desc, 'Fast');
    expect(g.releaseDate, '2011');
    expect(g.publisher, 'Acme');
    expect(g.romPath, p.normalize(p.join(dir.path, 'Racer [X].7z')));
    expect(g.images['boxart'],
        p.join(dir.path, 'media', 'images', 'Racer [X].png'));
    expect(g.images['support'],
        p.join(dir.path, 'media', 'support', 'Racer [X].png'));
    expect(g.images.containsKey('screenshot'), isFalse);
  });

  test('non-datafile xml returns empty', () {
    final f = write('x.dat', '<gameList><game><path>./a</path></game></gameList>');
    expect(parseDat(f), isEmpty);
  });

  test('game without <rom> is skipped', () {
    final f = write('y.dat',
        '<datafile><game name="A"><year>2000</year></game></datafile>');
    expect(parseDat(f), isEmpty);
  });
}
