import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/scraped_game.dart';
import 'package:rarm/services/scraper/scraped_store.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ss'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('putAll then get round-trips, case-insensitive lookup', () async {
    final store = ScrapedStore(baseDir: dir);
    await store.putAll([
      const ScrapedGame(romPath: r'C:\roms\psx\Racer.zip', title: 'Racer'),
    ]);
    expect(store.get(r'C:\roms\psx\racer.zip')?.title, 'Racer'); // diff case
  });

  test('persists across instances', () async {
    await ScrapedStore(baseDir: dir).putAll(
        [const ScrapedGame(romPath: '/a/b.zip', title: 'B')]);
    final store = ScrapedStore(baseDir: dir);
    await store.load();
    expect(store.get('/a/b.zip')?.title, 'B');
  });

  test('seed puts straight into memory with a normalized key', () {
    final store = ScrapedStore(baseDir: dir);
    store.seed(const ScrapedGame(romPath: r'C:\roms\ps3\Game.iso', title: 'G'));
    expect(store.get(r'c:\roms\ps3\game.iso')?.title, 'G'); // diff case
  });

  test('miss returns null', () async {
    final store = ScrapedStore(baseDir: dir);
    await store.load();
    expect(store.get('/nope'), isNull);
  });
}
