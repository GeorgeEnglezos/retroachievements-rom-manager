import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/file_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moveToRecycleBin idempotency', () {
    test('returns true when the file is already gone', () async {
      // A path that doesn't exist: the recycle command errors (exit != 0) but
      // the goal state, file absent, is already met, so it must succeed.
      final missing =
          p.join(Directory.systemTemp.path, 'ra-rom-mgr-not-here-12345.bin');
      expect(File(missing).existsSync(), isFalse);
      expect(await FileActions.moveToRecycleBin(missing), isTrue);
    });
  });

  group('isConsoleExe', () {
    // Minimal PE: 'MZ', the header offset at 0x3c, then Subsystem 0x5c into
    // the PE header. Enough for the field the launcher reads.
    File writePe(String name, int subsystem) {
      const peOffset = 0x100;
      final bytes = Uint8List(peOffset + 0x5e);
      bytes[0] = 0x4D; // M
      bytes[1] = 0x5A; // Z
      ByteData.sublistView(bytes).setUint32(0x3c, peOffset, Endian.little);
      ByteData.sublistView(bytes)
          .setUint16(peOffset + 0x5c, subsystem, Endian.little);
      final file = File(p.join(
          Directory.systemTemp.createTempSync('rarm-pe').path, name));
      file.writeAsBytesSync(bytes);
      return file;
    }

    test('reads subsystem 3 as a console program', () {
      expect(FileActions.isConsoleExe(writePe('console.exe', 3).path), isTrue);
    });

    test('reads subsystem 2 as a GUI program', () {
      expect(FileActions.isConsoleExe(writePe('gui.exe', 2).path), isFalse);
    });

    test('a file that is not a PE is not a console program', () {
      final txt = File(p.join(
          Directory.systemTemp.createTempSync('rarm-pe').path, 'notpe.exe'));
      txt.writeAsStringSync('not an executable, just some bytes on disk');
      expect(FileActions.isConsoleExe(txt.path), isFalse);
    });

    test('a missing file is not a console program', () {
      expect(
          FileActions.isConsoleExe(
              p.join(Directory.systemTemp.path, 'rarm-absent-99999.exe')),
          isFalse);
    });
  });

  group('FileActions URL builders', () {
    test('raGameUrl builds the game page url', () {
      expect(FileActions.raGameUrl(1234),
          'https://retroachievements.org/game/1234');
    });

    test('raSupportedListUrl uses the console games page when known', () {
      expect(FileActions.raSupportedListUrl(7),
          'https://retroachievements.org/system/7/games');
    });

    test('raSupportedListUrl falls back to the full game list when unknown', () {
      expect(FileActions.raSupportedListUrl(null),
          'https://retroachievements.org/gameList.php');
    });

    test('googleSearchUrl strips () and [] blocks, appends folder name', () {
      final url = FileActions.googleSearchUrl(
          r'C:\ROMs\Genesis\Turbo Runner (USA) [v1.1].md');
      expect(url, startsWith('https://www.google.com/search?q='));
      expect(url, contains('Turbo'));
      expect(url, contains('Genesis'));
      expect(url, isNot(contains('(USA)')));
      expect(url, isNot(contains('[v1.1]')));
      expect(url, isNot(contains('.md')));
      expect(url, isNot(contains(' '))); // spaces must be encoded
    });
  });

  group('tokenizeCommand', () {
    test('splits a quoted exe path with spaces into one token', () {
      expect(
        FileActions.tokenizeCommand(r'"C:\Program Files\emu.exe" "{file.path}"'),
        [r'C:\Program Files\emu.exe', '{file.path}'],
      );
    });

    test('keeps RetroArch core flag before the path', () {
      expect(
        FileActions.tokenizeCommand(
            r'retroarch.exe -L ".\cores\snes9x.dll" "{file.path}"'),
        [r'retroarch.exe', '-L', r'.\cores\snes9x.dll', '{file.path}'],
      );
    });

    test('collapses runs of whitespace and ignores trailing spaces', () {
      expect(FileActions.tokenizeCommand('  a   b  '), ['a', 'b']);
    });

    test('empty string yields no tokens', () {
      expect(FileActions.tokenizeCommand('   '), isEmpty);
    });

    test('single quotes group a path with spaces', () {
      expect(
        FileActions.tokenizeCommand(r"'C:\Program Files\emu.exe' '{file.path}'"),
        [r'C:\Program Files\emu.exe', '{file.path}'],
      );
    });

    test('tabs separate tokens', () {
      expect(FileActions.tokenizeCommand('emu.exe\t-f\trom'),
          ['emu.exe', '-f', 'rom']);
    });

    test('unterminated quote yields no tokens', () {
      expect(FileActions.tokenizeCommand(r'"C:\Program Files\emu.exe'), isEmpty);
    });
  });
}
