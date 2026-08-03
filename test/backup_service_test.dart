import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup then restore round-trips data files and prefs', () async {
    final src = Directory.systemTemp.createTempSync('rav_backup_src');
    final dst = Directory.systemTemp.createTempSync('rav_backup_dst');
    final zip = p.join(Directory.systemTemp.path,
        'rav_backup_${DateTime.now().microsecondsSinceEpoch}.zip');
    addTearDown(() {
      src.deleteSync(recursive: true);
      dst.deleteSync(recursive: true);
      final f = File(zip);
      if (f.existsSync()) f.deleteSync();
    });

    // Seed source data dir + prefs.
    final dataFile = File(p.join(src.path, 'data', 'systems', 'a.json'));
    dataFile.parent.createSync(recursive: true);
    dataFile.writeAsStringSync('{"hello":"world"}');
    SharedPreferences.setMockInitialValues({
      'ra_username': 'bob',
      'home_combine_systems': true,
      'enabled_extensions': 'nes, snes',
    });

    await BackupService(baseDir: src).create(zip);
    expect(File(zip).existsSync(), isTrue);

    // Wipe prefs, restore into a fresh dir.
    SharedPreferences.setMockInitialValues({});
    await BackupService(baseDir: dst).restore(zip);

    final restored =
        File(p.join(dst.path, 'data', 'systems', 'a.json'));
    expect(restored.existsSync(), isTrue);
    expect(restored.readAsStringSync(), '{"hello":"world"}');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ra_username'), 'bob');
    expect(prefs.getBool('home_combine_systems'), isTrue);
    expect(prefs.getString('enabled_extensions'), 'nes, snes');
  });
}
