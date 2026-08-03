import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/scraper/gamelist_parser.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('gl'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, String content) {
    final f = File(p.join(dir.path, name))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('parses fields, resolves existing image paths, skips missing files', () {
    write('media/box/Racer.png', 'x'); // exists
    // media/snap/Racer.png intentionally NOT created
    final gl = write('gamelist.xml', '''
<gameList>
  <game>
    <path>./Racer.zip</path>
    <name>Test Racer</name>
    <desc>A game</desc>
    <publisher>Acme</publisher>
    <genre>Racing</genre>
    <releasedate>19960115T000000</releasedate>
    <thumbnail>./media/box/Racer.png</thumbnail>
    <image>./media/snap/Racer.png</image>
  </game>
</gameList>''');

    final games = parseGamelist(gl);
    expect(games, hasLength(1));
    final g = games.single;
    expect(g.title, 'Test Racer');
    expect(g.publisher, 'Acme');
    expect(g.releaseDate, '1996-01-15');
    expect(g.romPath, p.normalize(p.join(dir.path, 'Racer.zip')));
    expect(g.images['boxart'], p.normalize(p.join(dir.path, 'media/box/Racer.png')));
    expect(g.images.containsKey('screenshot'), isFalse); // file missing -> skipped
  });

  test('year-only releasedate normalizes to YYYY', () {
    final gl = write('gamelist.xml', '''
<gameList><game><path>./A.zip</path><name>A</name>
<releasedate>19990000T000000</releasedate></game></gameList>''');
    expect(parseGamelist(gl).single.releaseDate, '1999');
  });

  test('game without <path> is skipped', () {
    final gl = write('gamelist.xml',
        '<gameList><game><name>NoPath</name></game></gameList>');
    expect(parseGamelist(gl), isEmpty);
  });
}
