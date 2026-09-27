import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Snapshots your real RARM library (already fetched from RetroAchievements)
/// into `tool/demo/demo_library.json` for the screenshot demo, minus anything
/// from franchises whose owners go after preservation and ROM sites. Re-run it
/// whenever the library or the app's data format changes:
///
///   dart run tool/demo/export_demo_data.dart
///
/// The output holds your real play history, so it is gitignored.

/// Matched case-insensitively against title, publisher, developer and file
/// name. ROM hacks go too: nearly all of them are hacks of these franchises.
const blocked = [
  'nintendo',
  'pokémon',
  'pokemon',
  'mario',
  'zelda',
  'kirby',
  'metroid',
  'wario',
  'donkey kong',
  'yoshi',
  'fire emblem',
  'star fox',
  'f-zero',
  'game freak',
  'hal laboratory',
  'intelligent systems',
  'creatures inc',
  'earthbound',
  'mother 3',
  'pikmin',
  'smash bros',
  'animal crossing',
  'xenoblade',
  'splatoon',
  'tetris',
  // Nintendo-published titles that carry no franchise word or publisher.
  'advance wars',
  'golden sun',
  'drill dozer',
  'custom robo',
  'kid icarus',
  'kururin',
  'luigi',
  'punch-out',
  'princess peach',
  'rhythm tengoku',
  'rhythm heaven',
  'stafy',
  'mother 1',
  'dk:',
  'donkey',
  'banjo',
  'goldeneye',
  'pikachu',
  'poké',
  'pokken',
  'picross',
  'excitebike',
  'ice climber',
  'wave race',
  'emerald imperium',
  // Tools and personal files that live in ROM folders.
  'hekate',
  'nethersx2',
  'xdelta',
  '.vpk',
  'george',
  'pokemini', // the Pokémon Mini console, whose logo is Pokémon branding
  '~hack~',
  '[hack]',
  '(hack)',
];

bool isBlocked(Map<String, dynamic> game) {
  final info = game['gameInfo'] as Map<String, dynamic>? ?? const {};
  final text = [
    game['fileName'],
    info['title'],
    info['publisher'],
    info['developer'],
  ].whereType<String>().join(' ').toLowerCase();
  return blocked.any(text.contains);
}

void main() {
  final base = p.join(
    Platform.environment['APPDATA']!,
    'com.georgeenglezos',
    'RA ROM Manager',
  );
  final systems = <Map<String, dynamic>>[];
  final keptIds = <int>{};
  var dropped = 0;

  final files = Directory(
    p.join(base, 'data', 'systems'),
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
  for (final f in files) {
    final s = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final systemPath = s['systemPath'] as String;
    final folder = p.windows.basename(systemPath);
    if (blocked.any(folder.toLowerCase().contains)) continue;
    final games = <Map<String, dynamic>>[];
    for (final g in (s['games'] as List).cast<Map<String, dynamic>>()) {
      if (isBlocked(g)) {
        dropped++;
        continue;
      }
      // Paths are rebuilt under the demo folder, so only the part below the
      // system folder is kept (subfolders such as multi-disc sets survive).
      final rel = p.windows.relative(g['filePath'] as String, from: systemPath);
      games.add({...g..remove('filePath'), 'relPath': rel});
      if (g['gameId'] is int) keptIds.add(g['gameId'] as int);
    }
    if (games.isEmpty) continue;
    systems.add({
      'folder': folder,
      'consoleId': s['consoleId'],
      'games': games,
    });
  }

  final prefs =
      jsonDecode(
            File(p.join(base, 'shared_preferences.json')).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final wantToPlay = [
    // Stored as a JSON-encoded string, not a list.
    for (final id
        in jsonDecode(prefs['flutter.ra_want_to_play_ids'] as String? ?? '[]')
            as List)
      if (keptIds.contains(id)) id,
  ];

  // View settings carry over so the demo looks like your app. Credentials,
  // paths (the folder, playlists, emulators) and caches stay behind.
  const private = {
    'ra_username',
    'ra_api_key',
    'ra_avatar_path',
    'ra_avatar_version',
    'last_folder',
    'setup_done',
    'playlists',
    'emulators',
    'console_connections',
    'recent_unlocks_cache',
    'ra_want_to_play_ids',
    'skipped_release',
    'device_preview.settings',
  };
  final viewPrefs = {
    for (final e in prefs.entries)
      if (!private.contains(e.key.replaceFirst('flutter.', '')))
        e.key.replaceFirst('flutter.', ''): e.value,
  };

  final out = File(p.join('tool', 'demo', 'demo_library.json'));
  out.writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'username': 'PixelPilgrim',
      'wantToPlay': wantToPlay,
      'prefs': viewPrefs,
      'systems': systems,
    }),
  );
  final kept = systems.fold<int>(0, (n, s) => n + (s['games'] as List).length);
  stdout.writeln(
    'Kept $kept games in ${systems.length} systems, '
    'dropped $dropped. Wrote ${out.path}',
  );
}
