import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/services/cull_store.dart';
import 'package:rarm/services/data_wipe.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/playlist_store.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory base;

  /// Writes to `<base>/<relative>`, creating parents.
  void seed(String relative, String text) {
    final f = File(p.join(base.path, p.joinAll(relative.split('/'))));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  bool exists(String relative) =>
      FileSystemEntity.typeSync(p.join(base.path, p.joinAll(relative.split('/')))) !=
      FileSystemEntityType.notFound;

  /// Seeds one of everything a wipe can reach, on disk and in prefs.
  void seedEverything() {
    seed('data/systems/a.json', '{}');
    seed('data/scraped.json', '{}');
    seed('data/ra_cache/console_1.json', '{}');
    seed('data/metadata_cache/prov_1.json', '{}');
    seed('raImageCache/cover.png', 'PNG');
    seed('raImageCache.json', '[]');
    seed('icons/1234.ico', 'ICO');
    seed('logs/session.log', 'keep me');
    SharedPreferences.setMockInitialValues({
      PrefKeys.raApiKey: 'SECRET',
      PrefKeys.raUsername: 'bob',
      'enabled_extensions': 'nes',
      'emulators': '[]',
      PrefKeys.playlists: '[]',
      PrefKeys.favoriteSystems: '["nes"]',
      PrefKeys.cullDecided: '["ra:1"]',
      PrefKeys.homeIgnoredSpotlights: ['ra:2'],
    });
  }

  DataWipe wipe() => DataWipe(baseDir: base, library: Library(baseDir: base));

  setUp(() {
    base = Directory.systemTemp.createTempSync('rav_wipe');
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().clear();
    CullStore().clear();
    addTearDown(() => base.deleteSync(recursive: true));
  });

  test('every target together leaves only logs, settings and the API key',
      () async {
    seedEverything();

    await wipe().clear(ClearTarget.values.toSet());

    for (final gone in [
      'data/systems/a.json',
      'data/scraped.json',
      'data/ra_cache',
      'data/metadata_cache',
      'raImageCache',
      'raImageCache.json',
    ]) {
      expect(exists(gone), isFalse, reason: '$gone should be deleted');
    }
    // Shortcut icons are not on the menu: nothing regenerates them, and a
    // shortcut already on the desktop would silently lose its picture.
    expect(exists('icons'), isTrue);
    // Logs are diagnostics, not user data, and someone wiping is usually
    // troubleshooting.
    expect(exists('logs/session.log'), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raApiKey), 'SECRET');
    expect(prefs.getString(PrefKeys.raUsername), 'bob');
    expect(prefs.getString('enabled_extensions'), 'nes');
    expect(prefs.getString('emulators'), '[]');
    expect(prefs.getString(PrefKeys.playlists), isNull);
    expect(prefs.getString(PrefKeys.favoriteSystems), isNull);
    expect(prefs.getString(PrefKeys.cullDecided), isNull);
    expect(prefs.getStringList(PrefKeys.homeIgnoredSpotlights), isNull);
  });

  // The whole point of the picker: one tick must not take the others with it.
  test('each target deletes only its own files', () async {
    seedEverything();
    await wipe().clear({ClearTarget.artwork});
    expect(exists('raImageCache'), isFalse);
    expect(exists('data/systems/a.json'), isTrue);
    expect(exists('data/ra_cache'), isTrue);

    seedEverything();
    await wipe().clear({ClearTarget.raData});
    expect(exists('data/ra_cache'), isFalse);
    expect(exists('data/metadata_cache'), isFalse);
    expect(exists('data/scraped.json'), isTrue);
    expect(exists('data/systems/a.json'), isTrue);

    seedEverything();
    await wipe().clear({ClearTarget.scrapedData});
    expect(exists('data/scraped.json'), isFalse);
    expect(exists('data/systems/a.json'), isTrue);
  });

  test('clearing scans leaves playlists and caches alone', () async {
    seedEverything();

    await wipe().clear({ClearTarget.scans});

    expect(exists('data/systems/a.json'), isFalse);
    expect(exists('data/ra_cache'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.playlists), '[]');
    expect(prefs.getString(PrefKeys.cullDecided), '["ra:1"]');
    // Dismissed Home spotlights only name games from a scan, so they go with it.
    expect(prefs.getStringList(PrefKeys.homeIgnoredSpotlights), isNull);
  });

  // A trash or favorite verdict files the game in the matching playlist, so
  // keeping verdicts without playlists would leave games judged, out of the
  // deck, and no longer in the list the verdict put them in.
  test('clearing playlists takes cull verdicts with it', () async {
    seedEverything();

    expect(expandTargets({ClearTarget.playlists}),
        containsAll([ClearTarget.playlists, ClearTarget.cullVerdicts]));

    await wipe().clear({ClearTarget.playlists});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.playlists), isNull);
    expect(prefs.getString(PrefKeys.cullDecided), isNull);
  });

  // The reverse is safe: a trashed game stays in Trash, it just re-enters
  // the deck.
  test('clearing cull verdicts leaves playlists standing', () async {
    seedEverything();

    await wipe().clear({ClearTarget.cullVerdicts});

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.cullDecided), isNull);
    expect(prefs.getString(PrefKeys.playlists), '[]');
    expect(prefs.getString(PrefKeys.favoriteSystems), '["nes"]');
  });

  // Each store caches its state and writes the whole cache back on the next
  // edit, so a wipe that only removed the pref would see it all reappear the
  // first time the user favorited something.
  test('the playlist and cull stores forget, not just the prefs', () async {
    final playlists = PlaylistStore();
    await playlists.toggleMember(favoritesId, 'ra:1');
    await CullStore().decide('ra:2', CullVerdict.keep);
    expect(playlists.isFavorite('ra:1'), isTrue);
    expect(await CullStore().decided(), contains('ra:2'));

    await wipe().clear({ClearTarget.playlists});

    expect(await playlists.playlistsContaining('ra:1'), isEmpty);
    expect(await CullStore().decided(), isEmpty);
  });

  test('clearing scans empties the in-memory library too', () async {
    final systemPath = p.join(base.path, 'nes');
    Directory(systemPath).createSync();
    final lib = Library(baseDir: base);
    await lib.save(SystemData(
      systemId: '',
      systemPath: systemPath,
      games: [GameEntry.unscanned(p.join(systemPath, 'blue-hedgehog.nes'))],
      dismissedDuplicatePairs: <String>{},
      consoleId: 7,
    ));
    expect(await lib.summaries(), isNotEmpty);

    await DataWipe(baseDir: base, library: lib).clear({ClearTarget.scans});

    expect(await lib.summaries(), isEmpty);
  });

  test('an empty selection deletes nothing', () async {
    seedEverything();

    await wipe().clear({});

    expect(exists('data/systems/a.json'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.playlists), '[]');
  });
}
