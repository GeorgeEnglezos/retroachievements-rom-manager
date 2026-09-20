import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/folder_sort.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/rom_filter.dart';

void main() {
  RomResult rom(String name,
      {RomStatus status = RomStatus.supported,
      String? title,
      String? genre,
      int? dupGroup}) {
    final r = RomResult(filePath: '/x/$name', fileName: name);
    r.status = status;
    r.gameTitle = title;
    r.genre = genre;
    r.duplicateGroupId = dupGroup;
    return r;
  }

  test('availableGenres is distinct, sorted, and skips empty', () {
    final roms = [
      rom('a', genre: 'RPG'),
      rom('b', genre: 'Action'),
      rom('c', genre: 'RPG'),
      rom('d', genre: ''),
      rom('e'),
    ];
    expect(availableGenres(roms), ['Action', 'RPG']);
  });

  test('availableTags collects filename labels case-insensitively sorted', () {
    final roms = [rom('Game (Japan).sfc'), rom('Other (USA).sfc')];
    final tags = availableTags(roms);
    expect(tags, containsAll(['Japan', 'USA']));
    expect(tags, List.of(tags)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
  });

  test('visibleRoms applies the filter with playlist membership', () {
    final a = rom('a.nes');
    final b = rom('b.nes');
    final f = const RomFilter(includePlaylistIds: {'pl1'});
    final membership = {
      'path:/x/a.nes': {'pl1'},
    };
    expect(visibleRoms([a, b], f, membership), [a]);
  });

  test('empty filter matches everything', () {
    const f = RomFilter();
    expect(f.matches(rom('a.nes'), playlistIdsForRom: const {}), isTrue);
  });

  test('text matches file name case-insensitively', () {
    const f = RomFilter(text: 'race');
    expect(f.matches(rom('Racer.md'), playlistIdsForRom: const {}), isTrue);
    expect(f.matches(rom('Blahblah.nes'), playlistIdsForRom: const {}), isFalse);
  });

  test('text matches game title', () {
    const f = RomFilter(text: 'sword');
    expect(
        f.matches(rom('rom1.sfc', title: 'The Legend of Sword'),
            playlistIdsForRom: const {}),
        isTrue);
  });

  test('genre filter', () {
    const f = RomFilter(genres: {'RPG'});
    expect(f.matches(rom('a', genre: 'RPG'), playlistIdsForRom: const {}), isTrue);
    expect(f.matches(rom('b', genre: 'Platformer'), playlistIdsForRom: const {}),
        isFalse);
  });

  test('status filter', () {
    const f = RomFilter(statuses: {RomStatus.unsupported});
    expect(
        f.matches(rom('a', status: RomStatus.unsupported),
            playlistIdsForRom: const {}),
        isTrue);
    expect(
        f.matches(rom('b', status: RomStatus.supported),
            playlistIdsForRom: const {}),
        isFalse);
  });

  test('onlyDuplicates', () {
    const f = RomFilter(onlyDuplicates: true);
    expect(f.matches(rom('a', dupGroup: 1), playlistIdsForRom: const {}), isTrue);
    expect(f.matches(rom('b'), playlistIdsForRom: const {}), isFalse);
  });

  test('include playlists: row must be in all included', () {
    const f = RomFilter(includePlaylistIds: {'favorites'});
    expect(f.matches(rom('a'), playlistIdsForRom: const {'favorites'}), isTrue);
    expect(f.matches(rom('b'), playlistIdsForRom: const {}), isFalse);
  });

  test('exclude playlists: row must be in none excluded', () {
    const f = RomFilter(excludePlaylistIds: {'favorites'});
    expect(f.matches(rom('a'), playlistIdsForRom: const {'favorites'}), isFalse);
    expect(f.matches(rom('b'), playlistIdsForRom: const {}), isTrue);
  });

  test('criteria combine with AND', () {
    const f = RomFilter(text: 'race', genres: {'Platformer'});
    expect(
        f.matches(rom('Racer.md', genre: 'Platformer'),
            playlistIdsForRom: const {}),
        isTrue);
    expect(
        f.matches(rom('Racer.md', genre: 'RPG'), playlistIdsForRom: const {}),
        isFalse);
  });

  group('progressStates filter', () {
    RomResult withProgress(String name, {int earned = 0, int total = 10}) {
      final r = RomResult(filePath: '/x/$name', fileName: name);
      r.status = RomStatus.supported;
      r.earnedAchievements = earned;
      r.achievementCount = total;
      return r;
    }

    test('empty progressStates matches everything', () {
      const f = RomFilter();
      expect(f.matches(withProgress('a', earned: 0), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 5), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('c', earned: 10), playlistIdsForRom: {}), isTrue);
    });

    test('notStarted matches only earned==0', () {
      const f = RomFilter(progressStates: {ProgressState.notStarted});
      expect(f.matches(withProgress('a', earned: 0), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 1), playlistIdsForRom: {}), isFalse);
    });

    test('started matches 1..total-1', () {
      const f = RomFilter(progressStates: {ProgressState.started});
      expect(f.matches(withProgress('a', earned: 5), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 0), playlistIdsForRom: {}), isFalse);
      expect(f.matches(withProgress('c', earned: 10), playlistIdsForRom: {}), isFalse);
    });

    test('mastered matches earned>=total', () {
      const f = RomFilter(progressStates: {ProgressState.mastered});
      expect(f.matches(withProgress('a', earned: 10), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 9), playlistIdsForRom: {}), isFalse);
    });

    test('a rom with no progress data fails every progress filter', () {
      final unsynced = RomResult(filePath: '/x/a', fileName: 'a')
        ..status = RomStatus.supported
        ..achievementCount = 10; // earned still null: never synced
      final noSet = RomResult(filePath: '/x/b', fileName: 'b')
        ..status = RomStatus.supported
        ..earnedAchievements = 0
        ..achievementCount = 0; // matched, but the game has no achievements
      final unfetched = RomResult(filePath: '/x/c', fileName: 'c')
        ..status = RomStatus.supported; // never fetched at all

      for (final state in ProgressState.values) {
        final f = RomFilter(progressStates: {state});
        expect(f.matches(unsynced, playlistIdsForRom: {}), isFalse,
            reason: 'unsynced vs $state');
        expect(f.matches(noSet, playlistIdsForRom: {}), isFalse,
            reason: 'no achievements vs $state');
        expect(f.matches(unfetched, playlistIdsForRom: {}), isFalse,
            reason: 'unfetched vs $state');
      }
    });

    test('multiple states use OR', () {
      const f = RomFilter(
          progressStates: {ProgressState.notStarted, ProgressState.mastered});
      expect(f.matches(withProgress('a', earned: 0), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 10), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('c', earned: 5), playlistIdsForRom: {}), isFalse);
    });

    test('nearComplete matches >=80% but not mastered', () {
      const f = RomFilter(progressStates: {ProgressState.nearComplete});
      expect(f.matches(withProgress('a', earned: 8), playlistIdsForRom: {}), isTrue);
      expect(f.matches(withProgress('b', earned: 9), playlistIdsForRom: {}), isTrue);
      // 50% is "started", not near complete.
      expect(f.matches(withProgress('c', earned: 5), playlistIdsForRom: {}), isFalse);
      // Fully mastered is its own state.
      expect(f.matches(withProgress('d', earned: 10), playlistIdsForRom: {}), isFalse);
    });
  });

  test('onlyNoAchievements keeps matched games with zero achievements', () {
    final noAch = RomResult(filePath: 'a.gba', fileName: 'a.gba')
      ..status = RomStatus.supported
      ..achievementCount = 0;
    final withAch = RomResult(filePath: 'b.gba', fileName: 'b.gba')
      ..status = RomStatus.supported
      ..achievementCount = 12;
    const f = RomFilter(onlyNoAchievements: true);
    expect(f.matches(noAch, playlistIdsForRom: const {}), isTrue);
    expect(f.matches(withAch, playlistIdsForRom: const {}), isFalse);
  });

  group('sortRoms', () {
    RomResult withCount(String name, int? count, {int players = 0}) {
      final r = rom(name);
      r.achievementCount = count;
      r.numPlayersCasual = players;
      return r;
    }

    List<String> names(List<RomResult> roms) => [for (final r in roms) r.fileName];

    test('alphabetical respects direction', () {
      final roms = [rom('c'), rom('a'), rom('b')];
      expect(
          names(sortRoms(roms,
              sort: FolderSort.alphabetical,
              ascending: true,
              hot: false)),
          ['a', 'b', 'c']);
      expect(
          names(sortRoms(roms,
              sort: FolderSort.alphabetical,
              ascending: false,
              hot: false)),
          ['c', 'b', 'a']);
    });

    test('null keys sink to the bottom regardless of direction', () {
      final roms = [withCount('none', null), withCount('low', 10), withCount('high', 90)];
      for (final asc in [true, false]) {
        final sorted = names(sortRoms(roms,
            sort: FolderSort.achievementCount,
            ascending: asc,
            hot: false));
        expect(sorted.last, 'none');
      }
    });

    test('hot overrides sort and ranks by casual players', () {
      final roms = [
        withCount('a', 90, players: 5),
        withCount('b', 10, players: 50),
      ];
      expect(
          names(sortRoms(roms,
              sort: FolderSort.alphabetical,
              ascending: true,
              hot: true)),
          ['b', 'a']);
    });

    test('does not mutate the input list', () {
      final roms = [rom('c'), rom('a')];
      sortRoms(roms,
          sort: FolderSort.alphabetical,
          ascending: true,
          hot: false);
      expect(names(roms), ['c', 'a']);
    });
  });
}
