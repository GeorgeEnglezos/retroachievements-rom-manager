import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/models/system_data.dart';
import 'package:rarm/services/home_index_builder.dart';
import 'package:rarm/services/scan_settings.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/models/user_progress.dart';

GameEntry matched(String path, {int earned = 0}) => GameEntry(
      filePath: path,
      fileName: path.split(RegExp(r'[\\/]')).last,
      fileSize: 10,
      md5: 'm',
      gameId: 1,
      matched: true,
      noMatch: false,
      lastScanned: DateTime.parse('2026-06-13T10:00:00.000'),
      gameInfo: GameInfo(
          gameId: 1, title: 'Game', consoleName: 'SNES', achievementCount: 5,
          imageIcon: '/i.png'),
      progress: earned == 0
          ? null
          : UserProgress(gameId: 1, earnedAchievements: earned, earnedHardcore: 0),
    );

void main() {
  final data = SystemData(
    systemId: 'id',
    systemPath: r'E:\ROMs\SNES',
    games: [matched(r'E:\ROMs\SNES\a.sfc', earned: 3), matched(r'E:\ROMs\SNES\b.sfc')],
    dismissedDuplicatePairs: const {},
  );

  test('summary counts games, scanned and with-achievements', () {
    final s = buildSummary(data,
        systemId: 'id', name: 'SNES', consoleId: 3);
    expect(s.totalGames, 2);
    expect(s.gamesScanned, 2);
    expect(s.gamesWithAchievements, 2); // both matched
    expect(s.totalSizeBytes, 20);
    expect(s.consoleId, 3);
  });

  test('search rows carry title, system name, icon and earned count', () {
    final rows = buildSearchRows(data, systemName: 'SNES');
    expect(rows, hasLength(2));
    final a = rows.firstWhere((r) => r.fileName == 'a.sfc');
    expect(a.title, 'Game');
    expect(a.systemName, 'SNES');
    expect(a.icon, '/i.png');
    expect(a.earnedAchievements, 3);
  });

  group('keep predicate filters excluded/ignored games', () {
    final withExtras = SystemData(
      systemId: 'id',
      systemPath: r'E:\ROMs\SNES',
      games: [
        matched(r'E:\ROMs\SNES\a.sfc', earned: 3),
        matched(r'E:\ROMs\SNES\bad.sfc'), // excluded
        matched(r'E:\ROMs\SNES\Hacks\c.sfc'), // under ignored subfolder
      ],
      dismissedDuplicatePairs: const {},
    );
    keep(GameEntry g) =>
        !ScanSettings.isFileExcluded(g.filePath, {r'e:\roms\snes\bad.sfc'}) &&
        !ScanSettings.isUnderIgnoredFolder(
            g.filePath, withExtras.systemPath, {'hacks'});

    test('summary counts only kept games', () {
      final s = buildSummary(withExtras,
          systemId: 'id', name: 'SNES', consoleId: 3, keep: keep);
      expect(s.totalGames, 1);
      expect(s.gamesScanned, 1);
      expect(s.totalSizeBytes, 10);
    });

    test('search rows drop excluded and ignored-folder games', () {
      final rows = buildSearchRows(withExtras, systemName: 'SNES', keep: keep);
      expect(rows.map((r) => r.fileName), ['a.sfc']);
    });
  });
}
