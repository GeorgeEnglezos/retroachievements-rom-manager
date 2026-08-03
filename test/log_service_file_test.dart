import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/log_service.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('log_service_test');
    await LogService.init(baseDir: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  File sessionFile() => Directory(LogService.logFolderPath!)
      .listSync()
      .whereType<File>()
      .single;

  // Back-to-back writes: an IOSink flushed per line throws "StreamSink is
  // bound to a stream" on the write behind it, which during a dense scan threw
  // straight out of LogService.info and aborted the sweep.
  test('every line reaches disk while the app is still running', () {
    for (var i = 0; i < 50; i++) {
      LogService.info('Test/burst', 'line $i');
    }

    final lines = sessionFile().readAsLinesSync();
    expect(lines, hasLength(50));
    expect(lines.first, contains('line 0'));
    expect(lines.last, contains('line 49'));
  });

  test('logs the level and source of each entry', () {
    LogService.error('Scan/hash', 'boom');

    expect(sessionFile().readAsStringSync(), contains('[ERROR  ] Scan/hash: boom'));
  });
}
