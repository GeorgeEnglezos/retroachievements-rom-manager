import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/home_index.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/user_progress.dart';
import 'package:rarm/services/home_dashboard.dart';
import 'package:rarm/services/library.dart';
import 'package:rarm/services/member_key.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRa extends RaService {
  _FakeRa() : super(username: 'u', apiKey: 'k');

  final fetched = <int>[];
  bool throwDetail = false;

  @override
  Future<(GameInfo, UserProgress)> getGameInfoAndUserProgress(
      int gameId) async {
    fetched.add(gameId);
    if (throwDetail) throw Exception('network down');
    return (
      GameInfo(
        gameId: gameId,
        title: 'Racer',
        consoleName: 'Mega Drive',
        consoleId: 1,
        achievementCount: 24,
        imageIcon: '/Images/icon.png',
        imageBoxArt: '/Images/box.png',
        imageIngame: '/Images/ingame.png',
      ),
      UserProgress(gameId: gameId, earnedAchievements: 5, earnedHardcore: 2),
    );
  }
}

RomResult _game(
  String path, {
  int total = 0,
  int earned = 0,
  int players = 0,
  int hardcore = 0,
  String? title,
  DateTime? lastPlayed,
  RaAward? award,
  int? gameId,
}) {
  return RomResult(filePath: path, fileName: p.basename(path))
    ..status = RomStatus.supported
    ..gameId = gameId
    ..gameTitle = title
    ..consoleName = 'SNES'
    ..achievementCount = total
    ..earnedAchievements = earned
    ..earnedHardcore = hardcore
    ..numPlayersCasual = players
    ..lastPlayed = lastPlayed
    ..highestAward = award;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spotlight is the highest-completion in-progress game', () {
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 2), // 20%
      _game('/b.sfc', total: 10, earned: 9), // 90%
    ]);
    expect(d.spotlight!.filePath, '/b.sfc');
  });

  test('mastered games are excluded from continue and mastery buckets', () {
    final d = buildHomeDashboard([
      _game('/done.sfc', total: 5, earned: 5),
      _game('/wip.sfc', total: 5, earned: 3),
    ]);
    final paths = [
      ...d.continuePlaying.map((r) => r.filePath),
      ...d.closestToMastery.map((r) => r.filePath),
    ];
    expect(paths, isNot(contains('/done.sfc')));
    expect(paths, contains('/wip.sfc'));
  });

  test('continue playing orders by recency, mastery orders by completion', () {
    final older = DateTime(2024, 1, 1);
    final newer = DateTime(2024, 6, 1);
    // A is further along but played longer ago; B is less complete but newer.
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 8, lastPlayed: older),
      _game('/b.sfc', total: 10, earned: 3, lastPlayed: newer),
    ]);
    expect(d.continuePlaying.first.filePath, '/b.sfc'); // recency
    expect(d.closestToMastery.first.filePath, '/a.sfc'); // completion
  });

  test('beat spotlight is the most-complete unbeaten game, not the mastery hero',
      () {
    final d = buildHomeDashboard([
      _game('/wip1.sfc', total: 10, earned: 9), // 90% -> mastery hero
      _game('/beaten.sfc', total: 10, earned: 7, award: RaAward.beatenHardcore),
      _game('/wip2.sfc', total: 10, earned: 5), // 50%, unbeaten -> beat hero
    ]);
    expect(d.spotlight!.filePath, '/wip1.sfc');
    // The 70% game is further along but already beaten, so it's skipped; the
    // 90% game is excluded because it's the mastery hero.
    expect(d.beatSpotlight!.filePath, '/wip2.sfc');
  });

  test('beat spotlight is null when every started game is already beaten', () {
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 6, award: RaAward.beatenHardcore),
      _game('/b.sfc', total: 10, earned: 3, award: RaAward.beatenSoftcore),
    ]);
    expect(d.beatSpotlight, isNull);
  });

  test('an ignored mastery candidate falls through to the next', () {
    final games = [
      _game('/best.sfc', total: 10, earned: 9, gameId: 1), // 90%
      _game('/next.sfc', total: 10, earned: 5, gameId: 2), // 50%
    ];
    final key = memberKeyFor(gameId: 1, filePath: '/best.sfc');
    final d = buildHomeDashboard(games, ignoredKeys: {key});
    expect(d.spotlight!.filePath, '/next.sfc');
  });

  test('an ignored beat candidate falls through to the next', () {
    final games = [
      _game('/mastery.sfc', total: 10, earned: 9, gameId: 1), // mastery hero
      _game('/beat1.sfc', total: 10, earned: 7, gameId: 2), // 70%
      _game('/beat2.sfc', total: 10, earned: 4, gameId: 3), // 40%
    ];
    final key = memberKeyFor(gameId: 2, filePath: '/beat1.sfc');
    final d = buildHomeDashboard(games, ignoredKeys: {key});
    expect(d.beatSpotlight!.filePath, '/beat2.sfc');
  });

  test('ignoring every candidate leaves the spotlight null', () {
    final games = [
      _game('/only.sfc', total: 10, earned: 5, gameId: 1),
    ];
    final key = memberKeyFor(gameId: 1, filePath: '/only.sfc');
    final d = buildHomeDashboard(games, ignoredKeys: {key});
    expect(d.spotlight, isNull);
  });

  test('unplayed games fall to popular, biggest community first', () {
    final d = buildHomeDashboard([
      _game('/small.sfc', total: 10, earned: 0, players: 100),
      _game('/big.sfc', total: 10, earned: 0, players: 900),
    ]);
    expect(d.continuePlaying, isEmpty);
    expect(d.popularUnplayed.map((r) => r.filePath).toList(),
        ['/big.sfc', '/small.sfc']);
    // No in-progress games, so the hero falls back to the most-wanted unplayed.
    expect(d.spotlight!.filePath, '/big.sfc');
  });

  test('the same game across two ROM libraries is counted once', () {
    // Two library folders hold the same RA game (same gameId) as different
    // files. It must not double up in any bucket or the stat strip.
    final d = buildHomeDashboard([
      _game('/libA/gow.chd', total: 40, earned: 10, gameId: 2782),
      _game('/libB/gow.chd', total: 40, earned: 10, gameId: 2782),
    ]);
    expect(d.continuePlaying.length, 1);
    expect(d.closestToMastery.length, 1);
    expect(d.stats.achievementsEarned, 10);
  });

  test('games without an achievement set are ignored', () {
    final d = buildHomeDashboard([
      _game('/nosets.sfc', total: 0, earned: 0),
    ]);
    expect(d.hasContent, isFalse);
    expect(d.stats.mastered, 0);
  });

  test('stats sum library totals across systems and earned achievements', () {
    final systems = [
      SystemSummary(
        systemPath: '/snes',
        systemId: '',
        name: 'SNES',
        consoleId: 3,
        totalGames: 40,
        gamesScanned: 40,
        gamesWithAchievements: 12,
        totalSizeBytes: 1000,
        lastScanned: null,
      ),
    ];
    final d = buildHomeDashboard([
      _game('/a.sfc', total: 10, earned: 10), // mastered, 10 earned
      _game('/b.sfc', total: 10, earned: 4), // 4 earned
    ], systems: systems);
    expect(d.stats.totalGames, 40);
    expect(d.stats.systems, 1);
    expect(d.stats.mastered, 1);
    expect(d.stats.achievementsEarned, 14);
    expect(d.stats.totalSizeBytes, 1000);
  });

  group('fetchSpotlightArt', () {
    late Directory dataDir;
    late Directory sysDir;
    late Library lib;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dataDir = Directory.systemTemp.createTempSync('hd_art_data');
      sysDir = Directory.systemTemp.createTempSync('hd_art_sys');
      lib = Library(baseDir: dataDir);
    });

    tearDown(() {
      dataDir.deleteSync(recursive: true);
      sysDir.deleteSync(recursive: true);
    });

    // What a scan leaves behind: named off the cached console list, with no
    // box art or screenshots.
    Future<String> seedDeferred(int gameId, String file) async {
      final filePath = p.join(sysDir.path, file);
      final data = await lib.load(sysDir.path);
      await lib.save(data.copyWith(
        systemPath: sysDir.path,
        consoleId: 1,
        games: [
          ...data.games,
          GameEntry(
            filePath: filePath,
            fileName: file,
            fileSize: 42,
            md5: 'abc\$gameId',
            gameId: gameId,
            matched: true,
            noMatch: false,
            lastScanned: DateTime(2026, 6, 1),
            gameInfo: GameInfo(
              gameId: gameId,
              title: 'Racer',
              consoleName: 'Mega Drive',
              consoleId: 1,
              achievementCount: 24,
            ),
            progress: null,
          ),
        ],
      ));
      return filePath;
    }

    test('fetches art for both banners and persists it', () async {
      final masteryPath = await seedDeferred(101, 'a.md');
      final beatPath = await seedDeferred(102, 'b.md');
      final dash = buildHomeDashboard([
        _game(masteryPath, total: 10, earned: 9, gameId: 101),
        _game(beatPath, total: 10, earned: 4, gameId: 102),
      ]);
      expect(dash.spotlight!.gameId, 101);
      expect(dash.beatSpotlight!.gameId, 102);
      final ra = _FakeRa();

      await fetchSpotlightArt(dash, library: lib, service: ra);

      expect(ra.fetched, [101, 102]);
      // Applied in memory so the banners can draw without a reload...
      expect(dash.spotlight!.heroArt, '/Images/ingame.png');
      // ...and the system's display name survives the RA payload.
      expect(dash.spotlight!.consoleName, 'SNES');
      // ...and persisted so the next Home load costs nothing.
      final stored = (await Library(baseDir: dataDir).load(sysDir.path)).games;
      expect(stored.every((g) => g.gameInfo!.imageIngame != null), isTrue);
    });

    test('skips a game that already has hero art', () async {
      final path = await seedDeferred(103, 'c.md');
      final rom = _game(path, total: 10, earned: 9, gameId: 103)
        ..imageIngame = '/Images/have.png';
      final ra = _FakeRa();

      await fetchSpotlightArt(buildHomeDashboard([rom]), library: lib, service: ra);

      expect(ra.fetched, isEmpty);
    });

    test('fetches a game only once per session, so a failed art lookup '
        'cannot loop through the library save it triggers', () async {
      final path = await seedDeferred(104, 'd.md');
      final dash =
          buildHomeDashboard([_game(path, total: 10, earned: 9, gameId: 104)]);
      final ra = _FakeRa();

      await fetchSpotlightArt(dash, library: lib, service: ra);
      await fetchSpotlightArt(dash, library: lib, service: ra);

      expect(ra.fetched, [104]);
    });

    test('a failed fetch leaves the stored entry alone', () async {
      final path = await seedDeferred(105, 'e.md');
      final dash =
          buildHomeDashboard([_game(path, total: 10, earned: 9, gameId: 105)]);
      final ra = _FakeRa()..throwDetail = true;

      await fetchSpotlightArt(dash, library: lib, service: ra);

      expect(dash.spotlight!.heroArt, isNull);
      expect((await lib.load(sysDir.path)).games.single.gameInfo!.imageIngame,
          isNull);
    });
  });
}
