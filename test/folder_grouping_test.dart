import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_stats.dart';
import 'package:rarm/models/home_sort.dart';
import 'package:rarm/services/folder_grouping.dart';

void main() {
  group('groupFoldersByConsoleId', () {
    test('merges folders that share a non-null id, in first-seen order', () {
      final groups = groupFoldersByConsoleId(
        ['/r/PS1 USA', '/r/SNES', '/r/PS1 Eur'],
        {'/r/PS1 USA': 12, '/r/SNES': 3, '/r/PS1 Eur': 12},
      );
      expect(groups.length, 2);
      expect(groups[0].consoleId, 12);
      expect(groups[0].folderPaths, ['/r/PS1 USA', '/r/PS1 Eur']);
      expect(groups[1].consoleId, 3);
      expect(groups[1].folderPaths, ['/r/SNES']);
    });

    test('null-id folders become their own single-path groups, after the rest',
        () {
      final groups = groupFoldersByConsoleId(
        ['/r/BIOS', '/r/PS1', '/r/Saves'],
        {'/r/BIOS': null, '/r/PS1': 12, '/r/Saves': null},
      );
      expect(groups[0].consoleId, 12);
      expect(groups[1].consoleId, isNull);
      expect(groups[1].folderPaths, ['/r/BIOS']);
      expect(groups[2].consoleId, isNull);
      expect(groups[2].folderPaths, ['/r/Saves']);
    });
  });

  group('aggregateFolderStats', () {
    test('sums numeric fields and uses a synthetic path', () {
      final agg = aggregateFolderStats(12, [
        FolderStats(
            path: 'a',
            totalGames: 10,
            totalSizeBytes: 100,
            gamesScanned: 8,
            gamesWithAchievements: 5,
            lastScanned: DateTime(2026, 1, 2)),
        FolderStats(
            path: 'b',
            totalGames: 3,
            totalSizeBytes: 50,
            gamesScanned: 3,
            gamesWithAchievements: 1,
            lastScanned: DateTime(2026, 1, 1)),
      ]);
      expect(agg.path, 'console:12');
      expect(agg.totalGames, 13);
      expect(agg.totalSizeBytes, 150);
      expect(agg.gamesScanned, 11);
      expect(agg.gamesWithAchievements, 6);
      expect(agg.lastScanned, DateTime(2026, 1, 1)); // earliest
    });

    test('lastScanned is null when any folder is unscanned', () {
      final agg = aggregateFolderStats(12, [
        FolderStats(path: 'a', totalGames: 1, lastScanned: DateTime(2026, 1, 2)),
        FolderStats(path: 'b', totalGames: 1), // lastScanned == null
      ]);
      expect(agg.lastScanned, isNull);
      expect(agg.achievementPercent, isNull);
    });

    test('empty list yields zeros and null lastScanned', () {
      final agg = aggregateFolderStats(7, []);
      expect(agg.totalGames, 0);
      expect(agg.lastScanned, isNull);
    });
  });

  group('compareByHomeSort', () {
    // All share console 3, so the system sort falls back to name.
    final items = [
      (name: 'Zelda', size: 100, games: 5, console: 3),
      (name: 'Aardvark', size: 300, games: 1, console: 3),
      (name: 'Mario', size: 200, games: 9, console: 3),
    ];

    List<String> sortedNames(HomeSort s) {
      final list = [...items]..sort((a, b) => compareByHomeSort(
            a,
            b,
            sort: s,
            name: (i) => i.name,
            sizeBytes: (i) => i.size,
            gameCount: (i) => i.games,
            consoleId: (i) => i.console,
          ));
      return [for (final i in list) i.name];
    }

    test('alphabetical sorts A-Z', () {
      expect(sortedNames(HomeSort.alphabetical), ['Aardvark', 'Mario', 'Zelda']);
    });
    test('size sorts largest first', () {
      expect(sortedNames(HomeSort.size), ['Aardvark', 'Mario', 'Zelda']);
    });
    test('fileCount sorts most games first', () {
      expect(sortedNames(HomeSort.fileCount), ['Mario', 'Zelda', 'Aardvark']);
    });
    test('system falls back to name within one manufacturer', () {
      expect(sortedNames(HomeSort.system), ['Aardvark', 'Mario', 'Zelda']);
    });
  });
}
