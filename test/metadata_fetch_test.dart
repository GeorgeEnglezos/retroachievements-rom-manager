import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_metadata.dart';
import 'package:rarm/services/metadata/metadata_provider.dart';
import 'package:rarm/services/metadata_cache.dart';
import 'package:rarm/services/metadata_fetch.dart';

class _FakeProvider implements MetadataProvider {
  final Map<String, GameMetadata> byName; // cleaned name -> match
  int calls = 0;
  final bool throwOnLookup;
  _FakeProvider(this.byName, {this.throwOnLookup = false});
  @override
  String get id => 'fake';
  @override
  String get label => 'Fake';
  @override
  bool supports(int consoleId) => true;
  @override
  Future<GameMetadata?> lookup({required String name, required int consoleId}) async {
    calls++;
    if (throwOnLookup) throw Exception('boom');
    return byName[name];
  }
}

void main() {
  // runMetadataFetch logs on error, which touches SchedulerBinding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mf'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('cleans names, matches, and reports metadata per file', () async {
    final provider = _FakeProvider({
      'Some Racer': const GameMetadata(providerId: 'fake', title: 'Some Racer'),
    });
    final results = <String, GameMetadata?>{};
    await runMetadataFetch(
      files: ['/roms/ps3/Some Racer (USA).iso', '/roms/ps3/Unknown Game.iso'],
      consoleId: -3,
      provider: provider,
      cache: MetadataCache(baseDir: dir),
      onResult: (path, meta) => results[path] = meta,
    );
    expect(results['/roms/ps3/Some Racer (USA).iso']!.title, 'Some Racer');
    expect(results['/roms/ps3/Unknown Game.iso'], isNull);
  });

  test('serves a second identical name from cache (no second lookup)', () async {
    final provider = _FakeProvider({
      'Some Racer': const GameMetadata(providerId: 'fake', title: 'Some Racer'),
    });
    final cache = MetadataCache(baseDir: dir);
    await runMetadataFetch(
      files: ['/a/Some Racer (USA).iso', '/b/Some Racer (EU).iso'],
      consoleId: -3,
      provider: provider,
      cache: cache,
      onResult: (path, meta) {},
    );
    expect(provider.calls, 1); // second file hit the cache
  });

  test('a lookup error falls back to null, sweep continues', () async {
    final provider = _FakeProvider(const {}, throwOnLookup: true);
    final results = <String, GameMetadata?>{};
    await runMetadataFetch(
      files: ['/a/x.iso', '/a/y.iso'],
      consoleId: -3,
      provider: provider,
      cache: MetadataCache(baseDir: dir),
      onResult: (path, meta) => results[path] = meta,
    );
    expect(results.length, 2);
    expect(results.values.every((m) => m == null), isTrue);
  });
}
