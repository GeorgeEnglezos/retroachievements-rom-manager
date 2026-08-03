import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/display_name.dart';

void main() {
  group('displayNameFor', () {
    test('systemName mode uses the RA console name', () {
      expect(
        displayNameFor(
          mode: NameMode.systemName,
          consoleId: 3,
          folderPaths: ['/roms/SNES'],
        ),
        'Super Nintendo',
      );
    });

    test('folderName mode uses the raw folder name', () {
      expect(
        displayNameFor(
          mode: NameMode.folderName,
          consoleId: 3,
          folderPaths: ['/roms/SNES'],
        ),
        'SNES',
      );
    });

    test('systemName falls back to folder name when console is unknown', () {
      expect(
        displayNameFor(
          mode: NameMode.systemName,
          consoleId: null,
          folderPaths: ['/roms/Mystery'],
        ),
        'Mystery',
      );
    });

    test('combined group joins folder names in folderName mode', () {
      expect(
        displayNameFor(
          mode: NameMode.folderName,
          consoleId: 3,
          folderPaths: ['/roms/SNES', '/roms/Super Nintendo'],
        ),
        'SNES / Super Nintendo',
      );
    });

    test('combined group uses single console name in systemName mode', () {
      expect(
        displayNameFor(
          mode: NameMode.systemName,
          consoleId: 3,
          folderPaths: ['/roms/SNES', '/roms/Super Nintendo'],
        ),
        'Super Nintendo',
      );
    });
  });
}
