import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/scan_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('excludedFiles is empty by default', () async {
    expect(await ScanSettings.excludedFiles(), isEmpty);
  });

  test('addExcludedFiles persists and round-trips, even with commas', () async {
    await ScanSettings.addExcludedFiles([r'C:\roms\a,b.nes', r'C:\roms\c.sfc']);
    expect(await ScanSettings.excludedFiles(),
        [r'C:\roms\a,b.nes', r'C:\roms\c.sfc']);
  });

  test('addExcludedFiles dedupes case-insensitively', () async {
    await ScanSettings.addExcludedFiles([r'C:\Roms\A.nes']);
    await ScanSettings.addExcludedFiles([r'c:\roms\a.nes', r'C:\Roms\B.nes']);
    final list = await ScanSettings.excludedFiles();
    expect(list.length, 2);
    expect(list.first, r'C:\Roms\A.nes'); // original casing kept
  });

  test('removeExcludedFile drops a case-insensitive match', () async {
    await ScanSettings.addExcludedFiles([r'C:\roms\a.nes', r'C:\roms\b.nes']);
    await ScanSettings.removeExcludedFile(r'C:\ROMS\A.NES');
    expect(await ScanSettings.excludedFiles(), [r'C:\roms\b.nes']);
  });

  test('isFileExcluded matches case-insensitively against a lowered set', () {
    final set = {r'c:\roms\a.nes'};
    expect(ScanSettings.isFileExcluded(r'C:\Roms\A.nes', set), isTrue);
    expect(ScanSettings.isFileExcluded(r'C:\Roms\B.nes', set), isFalse);
  });

  group('isUnderIgnoredFolder', () {
    const ignored = {'bios'};
    test('true when a folder below the root matches (either separator)', () {
      expect(
          ScanSettings.isUnderIgnoredFolder(
              r'C:\roms\snes\BIOS\x.bin', r'C:\roms\snes', ignored),
          isTrue);
      expect(
          ScanSettings.isUnderIgnoredFolder(
              '/roms/snes/bios/x.bin', '/roms/snes', ignored),
          isTrue);
    });

    test('false for a file sitting directly in the root', () {
      expect(
          ScanSettings.isUnderIgnoredFolder(
              r'C:\roms\snes\game.sfc', r'C:\roms\snes', ignored),
          isFalse);
    });

    test('an ignored name above the root does not hide everything', () {
      expect(
          ScanSettings.isUnderIgnoredFolder(
              r'C:\bios\roms\game.sfc', r'C:\bios\roms', ignored),
          isFalse);
    });

    test('empty ignore set is always false', () {
      expect(
          ScanSettings.isUnderIgnoredFolder(
              r'C:\roms\bios\x.bin', r'C:\roms', <String>{}),
          isFalse);
    });
  });

  test('enabledExtensions unions disc formats into a stale saved list', () async {
    // Simulates a user whose saved list predates disc-format support.
    await ScanSettings.setEnabledExtensions('nes, snes, iso');
    final ext = await ScanSettings.enabledExtensions();
    expect(ext, containsAll(['nes', 'snes', 'iso']));
    expect(ext, containsAll(['rvz', 'gcm', 'wbfs', 'min', '7z']));
  });

  test('text round-trips one path per line', () async {
    await ScanSettings.setExcludedFilesFromText('C:\\roms\\a.nes\n C:\\roms\\b.nes \n\n');
    expect(await ScanSettings.excludedFiles(), [r'C:\roms\a.nes', r'C:\roms\b.nes']);
    expect(await ScanSettings.excludedFilesText(), 'C:\\roms\\a.nes\nC:\\roms\\b.nes');
  });

  test('ignored folders round-trip add then remove', () async {
    await ScanSettings.addIgnoredFolder('BIOS');
    await ScanSettings.addIgnoredFolder('Media');
    expect(await ScanSettings.ignoredFolders(), ['BIOS', 'Media']);

    await ScanSettings.removeIgnoredFolder('BIOS');
    expect(await ScanSettings.ignoredFolders(), ['Media']);
  });

  test('removing an ignored folder ignores case', () async {
    await ScanSettings.addIgnoredFolder('BIOS');
    // The wizard passes the on-disk folder name, which need not match the
    // case that was stored.
    await ScanSettings.removeIgnoredFolder('bios');
    expect(await ScanSettings.ignoredFolders(), isEmpty);
  });

  test('removing a folder that was never ignored leaves the list alone',
      () async {
    await ScanSettings.addIgnoredFolder('BIOS');
    await ScanSettings.removeIgnoredFolder('Saves');
    expect(await ScanSettings.ignoredFolders(), ['BIOS']);
  });

  // Home and Storage cache the filters (the shell's IndexedStack keeps them
  // alive, so initState never runs again). Every write has to publish, or a
  // Settings edit stays invisible until the next launch.
  group('scanFiltersListenable', () {
    var bumps = 0;
    void count() => bumps++;

    setUp(() {
      bumps = 0;
      scanFiltersListenable.addListener(count);
    });
    tearDown(() => scanFiltersListenable.removeListener(count));

    test('every filter write publishes a change', () async {
      await ScanSettings.setEnabledExtensions('nes');
      expect(bumps, 1, reason: 'extensions');

      await ScanSettings.setIgnoredFolders('BIOS');
      expect(bumps, 2, reason: 'ignored folders');

      await ScanSettings.addIgnoredFolder('Saves');
      expect(bumps, 3, reason: 'add ignored folder');

      await ScanSettings.removeIgnoredFolder('Saves');
      expect(bumps, 4, reason: 'remove ignored folder');

      await ScanSettings.setExcludedFiles([r'C:\roms\a.nes']);
      expect(bumps, 5, reason: 'excluded files');

      await ScanSettings.addExcludedFiles([r'C:\roms\b.nes']);
      expect(bumps, 6, reason: 'add excluded file');

      await ScanSettings.removeExcludedFile(r'C:\roms\b.nes');
      expect(bumps, 7, reason: 'remove excluded file');

      await ScanSettings.setExcludedFilesFromText(r'C:\roms\c.nes');
      expect(bumps, 8, reason: 'excluded files from text');
    });

    test('a no-op write publishes nothing', () async {
      await ScanSettings.addIgnoredFolder('BIOS');
      bumps = 0;
      await ScanSettings.addIgnoredFolder('bios'); // already there
      await ScanSettings.removeIgnoredFolder('Saves'); // never there
      expect(bumps, 0);
    });
  });
}
