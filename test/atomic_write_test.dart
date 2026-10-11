import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/atomic_write.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rarm_atomic');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  test('replaces an existing file and leaves no temp file behind', () async {
    final f = File(p.join(dir.path, 'store.json'))..writeAsStringSync('old');
    await writeAtomic(f, '{"new":true}');
    expect(f.readAsStringSync(), '{"new":true}');
    expect(dir.listSync().map((e) => p.basename(e.path)), ['store.json']);
  });

  test('a stale temp file from a crashed write is overwritten', () async {
    File(p.join(dir.path, 'store.json.tmp')).writeAsStringSync('half');
    final f = File(p.join(dir.path, 'store.json'));
    await writeAtomic(f, 'whole');
    expect(f.readAsStringSync(), 'whole');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });
}
