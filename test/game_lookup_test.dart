import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/game_metadata.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/models/user_progress.dart';
import 'package:rarm/services/game_lookup.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameInfo _info() => GameInfo(
      gameId: 7,
      title: 'Racer',
      consoleName: 'Genesis',
      consoleId: 1,
      achievementCount: 24,
      imageIcon: '/Images/icon.png',
      imageBoxArt: '/Images/box.png',
      imageTitle: '/Images/title.png',
      imageIngame: '/Images/ingame.png',
      publisher: 'Sega',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('applyGameInfo', () {
    test('copies fields including screenshots and sets supported', () {
      final rom = RomResult(filePath: 'C:/g/dashrunner.md', fileName: 'dashrunner.md');
      applyGameInfo(rom, _info());
      expect(rom.status, RomStatus.supported);
      expect(rom.gameId, 7);
      expect(rom.gameTitle, 'Racer');
      expect(rom.imageBoxArt, '/Images/box.png');
      expect(rom.imageTitle, '/Images/title.png');
      expect(rom.imageIngame, '/Images/ingame.png');
    });

    test('null info marks the rom unsupported', () {
      final rom = RomResult(filePath: 'C:/g/x.md', fileName: 'x.md');
      applyGameInfo(rom, null);
      expect(rom.status, RomStatus.unsupported);
    });
  });

  group('applyMetadata', () {
    test('copies fields and sets metadataOnly', () {
      final rom = RomResult(filePath: 'ps3/r.iso', fileName: 'r.iso');
      applyMetadata(
          rom,
          const GameMetadata(
            providerId: 'ss',
            title: 'Racer',
            publisher: 'Acme',
            genre: 'Racing',
            imageUrl: 'https://cdn/r.png',
            matchConfidence: 0.9,
          ));
      expect(rom.status, RomStatus.metadataOnly);
      expect(rom.gameTitle, 'Racer');
      expect(rom.publisher, 'Acme');
      expect(rom.imageUrl, 'https://cdn/r.png');
      expect(rom.lowConfidenceMatch, isFalse);
    });

    test('flags a low-confidence match', () {
      final rom = RomResult(filePath: 'ps3/r.iso', fileName: 'r.iso');
      applyMetadata(rom,
          const GameMetadata(providerId: 'ss', title: 'Racer', matchConfidence: 0.4));
      expect(rom.lowConfidenceMatch, isTrue);
    });

    test('null metadata leaves the row local-only', () {
      final rom = RomResult(filePath: 'ps3/r.iso', fileName: 'r.iso');
      applyMetadata(rom, null);
      expect(rom.status, RomStatus.localOnly);
    });
  });

  group('romFromEntry', () {
    GameEntry entry({
      bool matched = false,
      bool noMatch = false,
      GameInfo? gameInfo,
      UserProgress? progress,
      int? hashConsoleId,
    }) =>
        GameEntry(
          filePath: 'g/dashrunner.md',
          fileName: 'dashrunner.md',
          fileSize: 42,
          md5: 'abc',
          gameId: 7,
          matched: matched,
          noMatch: noMatch,
          lastScanned: DateTime(2026, 6, 1),
          gameInfo: gameInfo,
          progress: progress,
          hashConsoleId: hashConsoleId,
        );

    test('matched entry produces a fully populated supported rom', () {
      final rom = romFromEntry(entry(
        matched: true,
        gameInfo: _info(),
        hashConsoleId: 1,
        progress: UserProgress(
          gameId: 7,
          earnedAchievements: 3,
          earnedHardcore: 2,
          lastPlayed: DateTime(2026, 5, 5),
        ),
      ));

      expect(rom.status, RomStatus.supported);
      expect(rom.fileSize, 42);
      expect(rom.md5Hash, 'abc');
      expect(rom.hashConsoleId, 1);
      expect(rom.gameId, 7);
      expect(rom.gameTitle, 'Racer');
      expect(rom.earnedAchievements, 3);
      expect(rom.earnedHardcore, 2);
      expect(rom.lastPlayed, DateTime(2026, 5, 5));
    });

    test('consoleName override wins over the gameInfo value', () {
      final rom = romFromEntry(entry(matched: true, gameInfo: _info()),
          consoleName: 'Mega Drive');
      expect(rom.consoleName, 'Mega Drive');
    });

    test('noMatch entry is unsupported when the hash console still applies', () {
      final rom = romFromEntry(entry(noMatch: true, hashConsoleId: 1),
          consoleId: 1);
      expect(rom.status, RomStatus.unsupported);
    });

    test('noMatch hashed under a different console id falls back to notFetched',
        () {
      final rom = romFromEntry(entry(noMatch: true, hashConsoleId: 99),
          consoleId: 1);
      expect(rom.status, RomStatus.notFetched);
    });

    test('never-scanned entry on an RA console is notFetched', () {
      final rom = romFromEntry(entry(), consoleId: 1); // Genesis (RA-supported)
      expect(rom.status, RomStatus.notFetched);
    });

    test('unscanned entry on a display-only console is localOnly', () {
      final rom = romFromEntry(entry(), consoleId: -3); // PlayStation 3
      expect(rom.status, RomStatus.localOnly);
      expect(rom.consoleId, -3);
      expect(rom.consoleName, 'PlayStation 3');
    });

    test('unidentified folder (null console) is localOnly', () {
      final rom = romFromEntry(entry(), consoleName: 'My Folder');
      expect(rom.status, RomStatus.localOnly);
      expect(rom.consoleName, 'My Folder');
    });

    test('display-only entry with metadata resolves metadataOnly', () {
      final e = GameEntry(
        filePath: 'ps3/racer.iso',
        fileName: 'racer.iso',
        fileSize: 1,
        md5: null,
        gameId: null,
        matched: false,
        noMatch: false,
        lastScanned: DateTime(2026, 7, 1),
        gameInfo: null,
        progress: null,
        metadata: const GameMetadata(providerId: 'ss', title: 'Racer'),
      );
      final rom = romFromEntry(e, consoleId: -3); // PS3
      expect(rom.status, RomStatus.metadataOnly);
      expect(rom.gameTitle, 'Racer');
      expect(rom.consoleName, 'PlayStation 3');
    });

    test('stale metadata from a removed provider falls back to localOnly', () {
      final e = GameEntry(
        filePath: 'ps3/racer.iso',
        fileName: 'racer.iso',
        fileSize: 1,
        md5: null,
        gameId: null,
        matched: false,
        noMatch: false,
        lastScanned: DateTime(2026, 7, 1),
        gameInfo: null,
        progress: null,
        metadata: const GameMetadata(providerId: 'wikidata', title: 'Racer'),
      );
      final rom = romFromEntry(e, consoleId: -3); // PS3
      expect(rom.status, RomStatus.localOnly);
      expect(rom.publisher, isNull);
    });

    test('matched entry on a display-only console still resolves supported', () {
      final rom = romFromEntry(
          entry(matched: true, gameInfo: _info()),
          consoleId: -3);
      expect(rom.status, RomStatus.supported);
    });
  });

  group('resolveRom', () {
    late Directory dataDir;
    late Directory sysDir;
    late Library lib;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dataDir = Directory.systemTemp.createTempSync('gl_data');
      sysDir = Directory.systemTemp.createTempSync('gl_sys');
      lib = Library(baseDir: dataDir);
    });

    tearDown(() {
      dataDir.deleteSync(recursive: true);
      sysDir.deleteSync(recursive: true);
    });

    Future<void> seed(GameEntry entry) async {
      await lib.save(SystemData(
        systemId: '',
        systemPath: sysDir.path,
        games: [entry],
        dismissedDuplicatePairs: <String>{},
        consoleId: 1,
      ));
    }

    GameEntry matchedEntry(String filePath) => GameEntry(
          filePath: filePath,
          fileName: p.basename(filePath),
          fileSize: null,
          md5: 'abc',
          gameId: 7,
          matched: true,
          noMatch: false,
          lastScanned: DateTime(2026, 6, 1),
          gameInfo: _info(),
          progress: null,
        );

    test('builds a RomResult for a matched file', () async {
      final filePath = p.join(sysDir.path, 'dashrunner.md');
      await seed(matchedEntry(filePath));

      final rom = await resolveRom(filePath, library: lib);

      expect(rom, isNotNull);
      expect(rom!.fileName, 'dashrunner.md');
      expect(rom.gameTitle, 'Racer');
      expect(rom.imageIngame, '/Images/ingame.png');
    });

    test('returns null when the file is in no scanned system', () async {
      final rom = await resolveRom(p.join(sysDir.path, 'unknown.md'),
          library: lib);
      expect(rom, isNull);
    });

    test('returns null when the entry is not matched', () async {
      final filePath = p.join(sysDir.path, 'notes.txt');
      await seed(GameEntry(
        filePath: filePath,
        fileName: 'notes.txt',
        fileSize: null,
        md5: null,
        gameId: null,
        matched: false,
        noMatch: true,
        lastScanned: DateTime(2026, 6, 1),
        gameInfo: null,
        progress: null,
      ));
      final rom = await resolveRom(filePath, library: lib);
      expect(rom, isNull);
    });
  });
}
