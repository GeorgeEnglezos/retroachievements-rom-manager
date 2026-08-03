import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raw_hash/raw_hash.dart';
import 'package:rarm/services/hash_service.dart';

// The native raw_hash library only exists after a platform build, so it is
// absent on a plain `flutter test` runner (e.g. CI's analyze-and-test job).
// Probe once; tests that need it are skipped rather than failed when missing.
final bool _nativeAvailable = () {
  try {
    RawHash.hashFile('__no_such_file__', 0);
    return true;
  } catch (_) {
    return false;
  }
}();

void main() {
  group('HashService.shouldUnzip', () {
    test('arcade zips are hashed by filename, never unpacked', () {
      // rcheevos hashes the archive filename for Arcade (console 27), so the
      // zip must be passed straight through.
      expect(HashService.shouldUnzip(r'C:\roms\Arcade\ffight.zip', 27), isFalse);
    });

    test('cartridge-console zips are unpacked', () {
      expect(HashService.shouldUnzip(r'C:\roms\NES\smb.zip', 7), isTrue);
    });

    test('non-zip files are never unpacked', () {
      expect(HashService.shouldUnzip(r'C:\roms\NES\smb.nes', 7), isFalse);
      expect(HashService.shouldUnzip(r'C:\roms\Arcade\sf2.7z', 27), isFalse);
    });
  });

  // Needs the native raw_hash library on the loader path (e.g. run with the
  // build output dir on PATH). Proves the rcheevos log callback is wired up.
  group('HashService.computeHash diagnostics', () {
    test('a failed hash returns null with a non-empty rcheevos log', () async {
      final tmp = File(p.join(Directory.systemTemp.path,
          'ravld_bad_${DateTime.now().microsecondsSinceEpoch}.cue'));
      tmp.writeAsStringSync('this is not a valid cue sheet');
      try {
        final r = await HashService.computeHash(tmp.path, 12); // 12 = PS1 (disc)
        expect(r.hash, isNull);
        expect(r.log, isNotEmpty);
      } finally {
        tmp.deleteSync();
      }
    }, skip: _nativeAvailable ? false : 'raw_hash native library unavailable');

    test('compressed disc image without a tool reports unsupported format',
        () async {
      final r = await HashService.computeHash('C:/roms/gc/game.rvz', 16);
      expect(r.hash, isNull);
      expect(r.unsupportedFormat, isTrue);
    });

    test('7z archive reports unsupported format instead of a garbage hash',
        () async {
      final r = await HashService.computeHash('C:/roms/snes/game.7z', 3);
      expect(r.hash, isNull);
      expect(r.unsupportedFormat, isTrue);
    });
  });
}
