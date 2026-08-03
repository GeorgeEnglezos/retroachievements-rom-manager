import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/rom_file_lister.dart';
import 'package:rarm/services/scan_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('romlist_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('lists matching files recursively with sizes', () async {
    final sub = Directory('${tmp.path}/snes')..createSync();
    File('${sub.path}/a.sfc').writeAsBytesSync([1, 2, 3]);
    File('${tmp.path}/b.nes').writeAsBytesSync([4, 5]);
    File('${tmp.path}/skip.txt').writeAsStringSync('no');

    // hasEnabledExtension strips the leading dot and lowercases before
    // checking the set, so entries must NOT include the leading dot.
    final files = await listRomFiles([tmp.path], {'sfc', 'nes'});

    final byName = {for (final f in files) f.path.split(Platform.pathSeparator).last: f};
    expect(byName.keys, containsAll(['a.sfc', 'b.nes']));
    expect(byName.containsKey('skip.txt'), isFalse);
    expect(byName['a.sfc']!.size, 3);
    expect(byName['b.nes']!.size, 2);
  });

  test('omits files the user has excluded', () async {
    final a = '${tmp.path}/a.sfc';
    final b = '${tmp.path}/b.sfc';
    File(a).writeAsBytesSync([1]);
    File(b).writeAsBytesSync([2]);
    await ScanSettings.addExcludedFiles([a]);

    final files = await listRomFiles([tmp.path], {'sfc'});

    expect(
      files.map((f) => f.path.replaceAll('\\', '/')),
      [b.replaceAll('\\', '/')],
    );
  });

  test('skips files inside a nested ignored folder', () async {
    File('${tmp.path}/keep.sfc').writeAsBytesSync([1]);
    final bios = Directory('${tmp.path}/BIOS')..createSync();
    File('${bios.path}/skip.sfc').writeAsBytesSync([2]);
    await ScanSettings.setIgnoredFolders('BIOS');

    final files = await listRomFiles([tmp.path], {'sfc'});

    expect(
      files.map((f) => f.path.split(Platform.pathSeparator).last),
      ['keep.sfc'],
    );
  });

  test('returns empty list for a missing folder', () async {
    final files = await listRomFiles(['${tmp.path}/does-not-exist'], {'nes'});
    expect(files, isEmpty);
  });

  test('a folder deleted mid-walk yields a partial list, not an exception',
      () async {
    // Enough entries that the walk spans several event-loop turns, so the
    // delete lands while the stream is still yielding.
    for (var i = 0; i < 200; i++) {
      final sub = Directory('${tmp.path}/sys$i')..createSync();
      File('${sub.path}/rom$i.sfc').writeAsBytesSync([1]);
    }

    final walk = listRomFiles([tmp.path], {'sfc'});
    await tmp.delete(recursive: true);

    // The point is that it completes at all; how far it got is timing.
    expect(await walk, isA<List<RomFile>>());
  });
}
