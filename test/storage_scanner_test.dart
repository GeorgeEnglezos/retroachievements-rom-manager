import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/storage_scanner.dart';

// Enables the ROM extensions used across these tests; ignore/exclude default
// to empty so most cases measure everything.
StorageFilter _filter({
  Set<String> ignored = const {},
  Set<String> excluded = const {},
  Set<String> ext = const {'nes', 'bin', 'sfc', 'xci', 'nsp'},
}) =>
    StorageFilter(ignored, excluded, ext);

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_scanner_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('returns a child per immediate file and subfolder', () async {
    await File('${root.path}/rom.nes').writeAsBytes(List.filled(100, 0));
    final sub = await Directory('${root.path}/sub').create();
    await File('${sub.path}/a.bin').writeAsBytes(List.filled(50, 0));

    final items = await childSizes((root.path, _filter()));

    expect(items.length, 2);
    final byName = {for (final i in items) i.label: i};
    expect(byName['rom.nes']!.bytes, 100);
    expect(byName['sub']!.bytes, 50);
  });

  test('subfolder size sums files recursively', () async {
    final sub = await Directory('${root.path}/sub').create();
    await File('${sub.path}/a.bin').writeAsBytes(List.filled(30, 0));
    final nested = await Directory('${sub.path}/nested').create();
    await File('${nested.path}/b.bin').writeAsBytes(List.filled(70, 0));

    final items = await childSizes((root.path, _filter()));

    expect(items.single.bytes, 100);
  });

  test('each child carries its full path for further drill-down', () async {
    final sub = await Directory('${root.path}/sub').create();
    await File('${sub.path}/a.bin').writeAsBytes(List.filled(10, 0));

    final items = await childSizes((root.path, _filter()));

    expect(p.equals(items.single.path!, sub.path), isTrue);
  });

  test('missing directory yields no children', () async {
    final items = await childSizes(('${root.path}/does_not_exist', _filter()));
    expect(items, isEmpty);
  });

  test('systemSizes reports filtered recursive size per path', () async {
    final sw = await Directory('${root.path}/switch').create();
    await File('${sw.path}/game.xci').writeAsBytes(List.filled(500, 0));
    final nested = await Directory('${sw.path}/dlc').create();
    await File('${nested.path}/patch.nsp').writeAsBytes(List.filled(300, 0));

    final sizes = await systemSizes(([sw.path], _filter()));

    expect(sizes[sw.path], 800);
  });

  test('non-ROM files are excluded from sizes and children', () async {
    await File('${root.path}/rom.nes').writeAsBytes(List.filled(100, 0));
    await File('${root.path}/readme.txt').writeAsBytes(List.filled(999, 0));

    final items = await childSizes((root.path, _filter()));
    final sizes = await systemSizes(([root.path], _filter()));

    expect(items.map((i) => i.label), ['rom.nes']);
    expect(sizes[root.path], 100);
  });

  test('excluded files are skipped', () async {
    final a = '${root.path}/a.nes';
    await File(a).writeAsBytes(List.filled(40, 0));
    await File('${root.path}/b.nes').writeAsBytes(List.filled(60, 0));

    final f = _filter(excluded: {a.toLowerCase().replaceAll('\\', '/')});
    final items = await childSizes((root.path, f));
    final sizes = await systemSizes(([root.path], f));

    expect(items.map((i) => i.label), ['b.nes']);
    expect(sizes[root.path], 60);
  });

  test('ignored subfolders are dropped from children and sizes', () async {
    await File('${root.path}/keep.nes').writeAsBytes(List.filled(20, 0));
    final bios = await Directory('${root.path}/BIOS').create();
    await File('${bios.path}/skip.bin').writeAsBytes(List.filled(80, 0));

    final f = _filter(ignored: {'bios'});
    final items = await childSizes((root.path, f));
    final sizes = await systemSizes(([root.path], f));

    expect(items.map((i) => i.label), ['keep.nes']);
    expect(sizes[root.path], 20);
  });

  test('a folder left empty by filtering does not appear', () async {
    final junk = await Directory('${root.path}/junk').create();
    await File('${junk.path}/notes.txt').writeAsBytes(List.filled(500, 0));
    await File('${root.path}/rom.nes').writeAsBytes(List.filled(10, 0));

    final items = await childSizes((root.path, _filter()));

    expect(items.map((i) => i.label), ['rom.nes']);
  });
}
