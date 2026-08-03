import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/scraper/gamelist_importer.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('imp'));
  tearDown(() => root.deleteSync(recursive: true));

  File write(String rel, String content) {
    final f = File(p.join(root.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('findScrapeSources finds gamelist.xml and .dat under root', () {
    write('psx/gamelist.xml', '<gameList/>');
    write('snes/gamelist.xml', '<gameList/>');
    write('ps3/Sony Playstation 3.dat', '<datafile/>');
    write('psx/Racer.zip', 'x');
    final found =
        findScrapeSources(root).map((f) => p.basename(f.path)).toList();
    expect(found, hasLength(3));
    expect(found.where((n) => n == 'gamelist.xml'), hasLength(2));
    expect(found.where((n) => n.endsWith('.dat')), hasLength(1));
  });

  test('importFrom imports a Logiqx .dat matched by rom filename', () {
    final dat = write('ps3/Sys.dat', '''
<datafile>
  <game name="Racer"><manufacturer>Acme</manufacturer>
    <rom name="Racer.iso" size="1" /></game>
</datafile>''');
    final racer = p.normalize(p.join(root.path, 'ps3', 'racer.iso')); // diff case
    final result = importFrom([dat], scannedRomPaths: {racer});
    expect(result.matched, hasLength(1));
    expect(result.matched.single.publisher, 'Acme');
  });

  test('importFrom keeps only games matching a scanned ROM (case-insensitive)', () {
    final gl = write('psx/gamelist.xml', '''
<gameList>
  <game><path>./Racer.zip</path><name>Racer</name></game>
  <game><path>./Ghost.zip</path><name>Ghost</name></game>
</gameList>''');
    final racer = p.normalize(p.join(root.path, 'psx', 'RACER.zip')); // diff case
    final result = importFrom([gl], scannedRomPaths: {racer});

    expect(result.matched, hasLength(1));
    expect(result.matched.single.title, 'Racer');
    expect(result.unmatched, 1); // Ghost had no scanned ROM
  });
}
