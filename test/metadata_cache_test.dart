import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_metadata.dart';
import 'package:rarm/services/metadata_cache.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mc'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('put then get round-trips an entry', () async {
    final cache = MetadataCache(baseDir: dir);
    await cache.put('ss', -3, 'racer',
        const GameMetadata(providerId: 'ss', title: 'Racer', genre: 'Racing'));
    final got = await cache.get('ss', -3, 'racer');
    expect(got!.title, 'Racer');
    expect(got.genre, 'Racing');
  });

  test('persists across instances', () async {
    await MetadataCache(baseDir: dir).put('ss', -3, 'racer',
        const GameMetadata(providerId: 'ss', title: 'Racer'));
    final got = await MetadataCache(baseDir: dir).get('ss', -3, 'racer');
    expect(got!.title, 'Racer');
  });

  test('miss returns null', () async {
    expect(await MetadataCache(baseDir: dir).get('ss', -3, 'nope'), isNull);
  });

  test('separates entries by provider and console', () async {
    final cache = MetadataCache(baseDir: dir);
    await cache.put('ss', -3, 'racer',
        const GameMetadata(providerId: 'ss', title: 'PS3 Racer'));
    await cache.put('ss', -1, 'racer',
        const GameMetadata(providerId: 'ss', title: 'Switch Racer'));
    expect((await cache.get('ss', -3, 'racer'))!.title, 'PS3 Racer');
    expect((await cache.get('ss', -1, 'racer'))!.title, 'Switch Racer');
  });
}
