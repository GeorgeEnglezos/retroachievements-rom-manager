import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/backup_service.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Writes [text] to `<dir>/<relative>`, creating parents.
File _seed(Directory dir, String relative, String text) {
  final f = File(p.join(dir.path, p.joinAll(relative.split('/'))));
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(text);
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory src;
  late Directory dst;
  late String zip;

  setUp(() {
    src = Directory.systemTemp.createTempSync('rav_backup_src');
    dst = Directory.systemTemp.createTempSync('rav_backup_dst');
    zip = p.join(Directory.systemTemp.path,
        'rav_backup_${DateTime.now().microsecondsSinceEpoch}.zip');
    addTearDown(() {
      src.deleteSync(recursive: true);
      dst.deleteSync(recursive: true);
      final f = File(zip);
      if (f.existsSync()) f.deleteSync();
    });
  });

  test('backup then restore round-trips every support folder and prefs',
      () async {
    _seed(src, 'data/systems/a.json', '{"hello":"world"}');
    // Artwork and icons live outside data/; they belong in the backup too.
    _seed(src, 'raImageCache/cover.png', 'PNG');
    _seed(src, 'icons/1234.ico', 'ICO');
    // Session logs are noise in a backup, and the live one is held open on
    // Windows.
    _seed(src, 'logs/session.log', 'noise');
    SharedPreferences.setMockInitialValues({
      PrefKeys.raUsername: 'bob',
      'home_combine_systems': true,
      'enabled_extensions': 'nes, snes',
    });

    await BackupService(baseDir: src).create(zip);
    expect(File(zip).existsSync(), isTrue);

    SharedPreferences.setMockInitialValues({});
    await BackupService(baseDir: dst).restore(zip);

    String read(String rel) =>
        File(p.join(dst.path, p.joinAll(rel.split('/')))).readAsStringSync();
    expect(read('data/systems/a.json'), '{"hello":"world"}');
    expect(read('raImageCache/cover.png'), 'PNG');
    expect(read('icons/1234.ico'), 'ICO');
    expect(Directory(p.join(dst.path, 'logs')).existsSync(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raUsername), 'bob');
    expect(prefs.getBool('home_combine_systems'), isTrue);
    expect(prefs.getString('enabled_extensions'), 'nes, snes');
    // The snapshot is applied, not left on disk for the next backup to re-zip.
    expect(File(p.join(dst.path, 'prefs.json')).existsSync(), isFalse);
  });

  test('the API key never leaves the machine in a backup', () async {
    _seed(src, 'data/systems/a.json', '{}');
    // On the SecretStore fallback path (a Linux box with no secret service)
    // the key really is a pref, so the filter has to hold there too.
    SharedPreferences.setMockInitialValues({
      PrefKeys.raApiKey: 'SECRET',
      PrefKeys.raUsername: 'bob',
    });
    await BackupService(baseDir: src).create(zip);

    expect(utf8.decode(File(zip).readAsBytesSync(), allowMalformed: true),
        isNot(contains('SECRET')));

    SharedPreferences.setMockInitialValues({PrefKeys.raApiKey: 'CURRENT'});
    await BackupService(baseDir: dst).restore(zip);
    final prefs = await SharedPreferences.getInstance();
    // Restoring must not wipe the key the user is signed in with either.
    expect(prefs.getString(PrefKeys.raApiKey), 'CURRENT');
    expect(prefs.getString(PrefKeys.raUsername), 'bob');
  });

  test('restore replaces current data instead of merging over it', () async {
    _seed(src, 'data/systems/kept.json', 'from backup');
    SharedPreferences.setMockInitialValues({PrefKeys.raUsername: 'bob'});
    await BackupService(baseDir: src).create(zip);

    // The live install has a system and a pref the backup knows nothing about.
    _seed(dst, 'data/systems/ghost.json', 'stale');
    SharedPreferences.setMockInitialValues({
      PrefKeys.raUsername: 'alice',
      'folder_sort': 'name',
    });
    await BackupService(baseDir: dst).restore(zip);

    expect(File(p.join(dst.path, 'data', 'systems', 'ghost.json')).existsSync(),
        isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raUsername), 'bob');
    expect(prefs.getString('folder_sort'), isNull);
  });

  test('restore rejects a zip that is not a RARM backup', () async {
    _seed(dst, 'data/systems/keep.json', 'mine');
    SharedPreferences.setMockInitialValues({PrefKeys.raUsername: 'alice'});
    // A zip with no prefs.json: any old archive the user picked by mistake.
    await BackupService(baseDir: src).create(zip);
    final notABackup = p.join(Directory.systemTemp.path, 'rav_other.zip');
    File(notABackup).writeAsBytesSync([0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0)]);
    addTearDown(() => File(notABackup).deleteSync());

    expect(BackupService(baseDir: dst).restore(notABackup), throwsA(anything));
    // Nothing was touched on the way to the rejection.
    expect(File(p.join(dst.path, 'data', 'systems', 'keep.json')).existsSync(),
        isTrue);
  });
}
