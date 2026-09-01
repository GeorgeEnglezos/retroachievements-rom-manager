import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/ra_service.dart';
import 'package:rarm/models/user_progress.dart';

void main() {
  group('GameInfo.fromJson consoleId', () {
    test('parses ConsoleID when present', () {
      final info = GameInfo.fromJson({
        'gameId': 1,
        'title': 'Racer',
        'consoleName': 'Genesis',
        'consoleId': 1,
        'achievementCount': 10,
      });
      expect(info.consoleId, 1);
    });

    test('consoleId is null when absent', () {
      final info = GameInfo.fromJson({
        'gameId': 1,
        'title': 'Racer',
        'consoleName': 'Genesis',
        'achievementCount': 10,
      });
      expect(info.consoleId, isNull);
    });

    test('round-trips through toJson', () {
      final info = GameInfo.fromJson({
        'gameId': 1,
        'title': 'Racer',
        'consoleName': 'Genesis',
        'consoleId': 1,
        'achievementCount': 10,
      });
      final back = GameInfo.fromJson(info.toJson());
      expect(back.consoleId, 1);
    });

    test('title and in-game images round-trip through toJson', () {
      final info = GameInfo.fromJson({
        'gameId': 1,
        'title': 'Racer',
        'consoleName': 'Genesis',
        'achievementCount': 10,
        'imageTitle': '/Images/title.png',
        'imageIngame': '/Images/ingame.png',
      });
      final back = GameInfo.fromJson(info.toJson());
      expect(back.imageTitle, '/Images/title.png');
      expect(back.imageIngame, '/Images/ingame.png');
    });
  });

  group('parseGameInfoAndProgress', () {
    Map<String, dynamic> response({
      int earned = 0,
      int earnedHardcore = 0,
      Map<String, dynamic>? achievements,
    }) =>
        {
          'Title': 'Cavern Runner',
          'ConsoleName': 'PlayStation',
          'ConsoleID': 12,
          'NumAchievements': 2,
          'NumDistinctPlayersCasual': 100,
          'NumDistinctPlayersHardcore': 50,
          'Points': 200,
          'NumAwardedToUser': earned,
          'NumAwardedToUserHardcore': earnedHardcore,
          'Achievements': achievements ??
              {
                '10': {
                  'ID': 10,
                  'Title': 'First',
                  'Description': 'Do first thing',
                  'Points': 5,
                  'BadgeName': '00010',
                  'DisplayOrder': 2,
                  'NumAwarded': 100,
                  'DateEarned': '2026-05-01 10:00:00',
                  'DateEarnedHardcore': null,
                },
                '20': {
                  'ID': 20,
                  'Title': 'Second',
                  'Description': 'Do second thing',
                  'Points': 10,
                  'BadgeName': '00020',
                  'DisplayOrder': 1,
                  'NumAwarded': 50,
                  'DateEarned': null,
                  'DateEarnedHardcore': null,
                },
              },
        };

    /// A payload with no Achievements map at all.
    Map<String, dynamic> bare() => {
          'Title': 'Racer',
          'ConsoleName': 'Genesis',
          'NumAchievements': 0,
          'NumAwardedToUser': 0,
          'NumAwardedToUserHardcore': 0,
        };

    test('parses GameInfo correctly', () {
      final (info, _) = parseHelper(response());
      expect(info.title, 'Cavern Runner');
      expect(info.consoleName, 'PlayStation');
      expect(info.achievementCount, 2);
    });

    test('captures ImageTitle and ImageIngame screenshots', () {
      final data = response()
        ..['ImageTitle'] = '/Images/0001.png'
        ..['ImageIngame'] = '/Images/0002.png';
      final (info, _) = parseHelper(data);
      expect(info.imageTitle, '/Images/0001.png');
      expect(info.imageIngame, '/Images/0002.png');
    });

    test('earned counts are captured', () {
      final (_, progress) = parseHelper(response(earned: 1, earnedHardcore: 0));
      expect(progress.earnedAchievements, 1);
      expect(progress.earnedHardcore, 0);
    });

    test('lastPlayed is max DateEarned across achievements', () {
      final (_, progress) = parseHelper(response(
        earned: 2,
        achievements: {
          '1': {'DateEarned': '2026-05-01 10:00:00'},
          '2': {'DateEarned': '2026-05-03 12:00:00'},
        },
      ));
      expect(progress.lastPlayed, DateTime.parse('2026-05-03 12:00:00'));
    });

    test('lastPlayed is null when no achievements earned', () {
      final (_, progress) = parseHelper(response(
        achievements: {
          '1': {'DateEarned': null},
          '2': {'DateEarned': null},
        },
      ));
      expect(progress.lastPlayed, isNull);
    });

    test('achievements are parsed, sorted by displayOrder, and flag earned', () {
      final (_, progress) = parseHelper(response());
      expect(progress.achievements, hasLength(2));
      expect(progress.achievements.map((a) => a.id), [20, 10]); // displayOrder
      expect(progress.achievements.firstWhere((a) => a.id == 10).isEarned,
          isTrue);
      expect(progress.achievements.firstWhere((a) => a.id == 20).isEarned,
          isFalse);
    });

    test('points is summed from achievement points', () {
      final (info, _) = parseHelper(response());
      expect(info.points, 15); // 5 + 10
    });

    test('no Achievements map: null points, empty achievement list', () {
      final (info, progress) = parseHelper(bare());
      expect(info.points, isNull);
      expect(progress.achievements, isEmpty);
    });

    test('captures per-achievement Type', () {
      final (_, progress) = parseHelper(response(
        achievements: {
          '1': {'ID': 1, 'DisplayOrder': 1, 'Type': 'progression'},
          '2': {'ID': 2, 'DisplayOrder': 2, 'Type': 'win_condition'},
          '3': {'ID': 3, 'DisplayOrder': 3}, // standard: no Type
        },
      ));
      final byId = {for (final a in progress.achievements) a.id: a};
      expect(byId[1]!.type, 'progression');
      expect(byId[2]!.type, 'win_condition');
      expect(byId[3]!.type, isNull);
    });

    test('captures top-level HighestAwardKind into progress', () {
      final data = response()
        ..['HighestAwardKind'] = 'completed'
        ..['HighestAwardDate'] = '2026-07-04 09:00:00';
      final (_, progress) = parseHelper(data);
      expect(progress.highestAward, RaAward.completed);
      expect(progress.highestAwardDate, DateTime.parse('2026-07-04 09:00:00'));
    });

    test('award defaults to none when absent', () {
      final (_, progress) = parseHelper(response());
      expect(progress.highestAward, RaAward.none);
    });
  });

  group('Achievement.fromJson', () {
    Map<String, dynamic> achJson({
      int id = 1,
      String title = 'My Badge',
      String description = 'Do the thing',
      int points = 10,
      String badgeName = '12345',
      int displayOrder = 1,
      int numAwarded = 500,
      int trueRatio = 33,
      String? dateEarned,
      String? dateEarnedHardcore,
    }) =>
        {
          'ID': id,
          'Title': title,
          'Description': description,
          'Points': points,
          'BadgeName': badgeName,
          'DisplayOrder': displayOrder,
          'NumAwarded': numAwarded,
          'TrueRatio': trueRatio,
          'DateEarned': dateEarned,
          'DateEarnedHardcore': dateEarnedHardcore,
        };

    test('parses all fields', () {
      final a = Achievement.fromJson(achJson(dateEarned: '2026-05-01 10:00:00'));
      expect(a.id, 1);
      expect(a.title, 'My Badge');
      expect(a.description, 'Do the thing');
      expect(a.points, 10);
      expect(a.badgeName, '12345');
      expect(a.displayOrder, 1);
      expect(a.numAwarded, 500);
      expect(a.trueRatio, 33);
      expect(a.dateEarned, DateTime.parse('2026-05-01 10:00:00'));
      expect(a.dateEarnedHardcore, isNull);
    });

    test('isEarned is true when dateEarned is set', () {
      final earned = Achievement.fromJson(achJson(dateEarned: '2026-05-01 10:00:00'));
      final unearned = Achievement.fromJson(achJson());
      expect(earned.isEarned, isTrue);
      expect(unearned.isEarned, isFalse);
    });

    test('round-trips through toJson', () {
      final original = Achievement.fromJson(achJson(dateEarned: '2026-05-01 10:00:00'));
      final back = Achievement.fromJson(original.toJson());
      expect(back.id, original.id);
      expect(back.title, original.title);
      expect(back.trueRatio, original.trueRatio);
      expect(back.dateEarned, original.dateEarned);
    });

    test('handles missing optional fields gracefully', () {
      final a = Achievement.fromJson({'ID': 5, 'Title': 'Sparse'});
      expect(a.id, 5);
      expect(a.points, 0);
      expect(a.badgeName, '');
      expect(a.isEarned, isFalse);
    });

    test('Type is captured, empty string normalised to null, round-trips', () {
      final missable =
          Achievement.fromJson(achJson()..['Type'] = 'missable');
      expect(missable.type, 'missable');
      expect(Achievement.fromJson(missable.toJson()).type, 'missable');
      // RA sends "" for a standard achievement; treat it as no type.
      expect(Achievement.fromJson(achJson()..['Type'] = '').type, isNull);
      expect(Achievement.fromJson(achJson()).type, isNull);
    });
  });

  group('parseGameList', () {
    List<dynamic> sample() => [
          {
            'ID': 1,
            'Title': 'Racer',
            'ConsoleID': 1,
            'ImageIcon': '/Images/001.png',
            'NumAchievements': 24,
            'Points': 400,
            'DateModified': '2026-01-02 03:04:05',
            'Hashes': ['ABC123', 'def456'],
          },
          {
            'ID': 2,
            'Title': 'Ecco',
            'ConsoleID': 1,
            'NumAchievements': 0,
            'Hashes': [],
          },
        ];

    test('parses id, title, points, achievement count', () {
      final entries = RaService.parseGameList(sample());
      expect(entries, hasLength(2));
      expect(entries.first.gameId, 1);
      expect(entries.first.title, 'Racer');
      expect(entries.first.points, 400);
      expect(entries.first.achievementCount, 24);
      expect(entries.first.imageIcon, '/Images/001.png');
    });

    test('hashes are lowercased for case-insensitive matching', () {
      final entries = RaService.parseGameList(sample());
      expect(entries.first.hashes, ['abc123', 'def456']);
    });

    test('dateModified parsed; null when absent', () {
      final entries = RaService.parseGameList(sample());
      expect(entries.first.dateModified,
          DateTime.parse('2026-01-02 03:04:05'));
      expect(entries[1].dateModified, isNull);
    });

    test('round-trips through toJson/fromJson', () {
      final entry = RaService.parseGameList(sample()).first;
      final back = RaGameListEntry.fromJson(entry.toJson());
      expect(back.gameId, 1);
      expect(back.hashes, ['abc123', 'def456']);
      expect(back.dateModified, DateTime.parse('2026-01-02 03:04:05'));
    });
  });

  group('parseCompletionProgress hardcore + date', () {
    Map<String, dynamic> payload() => {
          'Count': 1,
          'Total': 1,
          'Results': [
            {
              'GameID': 5,
              'Title': 'Crash',
              'ConsoleName': 'PS1',
              'NumAwarded': 3,
              'NumAwardedHardcore': 2,
              'MaxPossible': 10,
              'MostRecentAwardedDate': '2026-05-03 12:00:00',
            }
          ],
        };

    test('captures hardcore count', () {
      final g = RaService.parseCompletionProgress(payload()).single;
      expect(g.numAwarded, 3);
      expect(g.numAwardedHardcore, 2);
    });

    test('captures lastPlayed from MostRecentAwardedDate', () {
      final g = RaService.parseCompletionProgress(payload()).single;
      expect(g.lastPlayed, DateTime.parse('2026-05-03 12:00:00'));
    });

    test('lastPlayed null when date absent', () {
      final data = payload();
      (data['Results'] as List).first.remove('MostRecentAwardedDate');
      final g = RaService.parseCompletionProgress(data).single;
      expect(g.lastPlayed, isNull);
    });

    test('maps HighestAwardKind to RaAward and captures the date', () {
      final data = payload();
      (data['Results'] as List).first
        ..['HighestAwardKind'] = 'beaten-hardcore'
        ..['HighestAwardDate'] = '2026-06-01 08:00:00';
      final g = RaService.parseCompletionProgress(data).single;
      expect(g.highestAward, RaAward.beatenHardcore);
      expect(g.highestAwardDate, DateTime.parse('2026-06-01 08:00:00'));
    });

    test('award is none and date null when absent', () {
      final g = RaService.parseCompletionProgress(payload()).single;
      expect(g.highestAward, RaAward.none);
      expect(g.highestAwardDate, isNull);
    });
  });

  group('raAwardFromKind', () {
    test('maps every RA kind and defaults unknown to none', () {
      expect(raAwardFromKind('beaten-softcore'), RaAward.beatenSoftcore);
      expect(raAwardFromKind('beaten-hardcore'), RaAward.beatenHardcore);
      expect(raAwardFromKind('completed'), RaAward.completed);
      expect(raAwardFromKind('mastered'), RaAward.mastered);
      expect(raAwardFromKind(null), RaAward.none);
      expect(raAwardFromKind('something-new'), RaAward.none);
    });
  });

}

(GameInfo, UserProgress) parseHelper(Map<String, dynamic> data) {
  return RaService.parseGameInfoAndProgress(1, data);
}
