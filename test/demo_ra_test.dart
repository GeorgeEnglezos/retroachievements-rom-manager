import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rarm/services/http_throttle.dart';
import 'package:rarm/services/ra_service.dart';

import '../tool/demo/demo_ra.dart';

// Drives the screenshot demo's fake RA through the real RaService parsers, so
// an app-side API change that breaks the demo fails here. The fixture is a
// cut-down library entry in the stored format export_demo_data.dart copies.
void main() {
  Map<String, dynamic> entry(
    int id, {
    required List<Map<String, dynamic>> achievements,
    String award = 'none',
  }) => {
    'fileName': 'Game $id (USA).gba',
    'relPath': 'Game $id (USA).gba',
    'fileSize': 1024,
    'gameId': id,
    'matched': true,
    'gameInfo': {
      'gameId': id,
      'title': 'Game $id',
      'consoleName': 'Game Boy Advance',
      'consoleId': 5,
      'achievementCount': achievements.length,
      'imageIcon': '/Images/$id.png',
      'publisher': 'Some Publisher',
    },
    'progress': {
      'gameId': id,
      'earnedAchievements': achievements
          .where((a) => a['DateEarned'] != null)
          .length,
      'earnedHardcore': achievements
          .where((a) => a['DateEarnedHardcore'] != null)
          .length,
      'lastPlayed': '2026-01-10T12:00:00.000Z',
      'highestAward': award,
      'achievements': achievements,
    },
  };

  Map<String, dynamic> ach(int id, {String? earned, bool hardcore = true}) => {
    'ID': id,
    'Title': 'Achievement $id',
    'Description': 'Do thing $id',
    'Points': 5,
    'BadgeName': '$id',
    'DisplayOrder': id,
    'DateEarned': earned,
    'DateEarnedHardcore': hardcore ? earned : null,
  };

  late List<Uri> artworkRequests;
  late DemoRa ra;
  late RaService service;

  setUp(() {
    artworkRequests = [];
    ra = DemoRa(
      {
        'username': 'Demo',
        'wantToPlay': [2],
        'systems': [
          {
            'folder': 'gba',
            'consoleId': 5,
            'games': [
              entry(
                1,
                award: 'beatenHardcore',
                achievements: [
                  ach(11, earned: '2026-01-05T10:00:00.000Z'),
                  ach(12, earned: '2026-01-09T10:00:00.000Z', hardcore: false),
                  ach(13),
                ],
              ),
              entry(2, achievements: [ach(21)]),
            ],
          },
        ],
      },
      artwork: MockClient((req) async {
        artworkRequests.add(req.url);
        return http.Response('png', 200);
      }),
    );
    service = RaService(
      username: ra.username,
      apiKey: 'demo',
      throttle: HttpThrottle(
        client: MockClient(ra.handle),
        minGap: Duration.zero,
      ),
    );
  });

  test(
    'game progress keeps the stored locked and unlocked achievements',
    () async {
      final (info, progress) = await service.getGameInfoAndUserProgress(1);
      expect(info.title, 'Game 1');
      expect(progress.earnedAchievements, 2);
      expect(progress.earnedHardcore, 1);
      expect(progress.achievements.where((a) => !a.isEarned).map((a) => a.id), [
        13,
      ]);
      expect(progress.highestAward, RaAward.beatenHardcore);
    },
  );

  test('completion lists only played games, award intact', () async {
    final played = await service.getUserCompletionProgress();
    expect(played.map((c) => c.gameId), [1]);
    expect(played.single.highestAward, RaAward.beatenHardcore);
  });

  test('earned-between honours the window, oldest first', () async {
    final unlocks = await service.getAchievementsEarnedBetween(
      from: DateTime.utc(2026, 1, 1),
      to: DateTime.utc(2026, 1, 8),
    );
    expect(unlocks.map((u) => u.title), ['Achievement 11']);
    final all = await service.getAchievementsEarnedBetween(
      from: DateTime.utc(2026),
      to: DateTime.utc(2027),
    );
    expect(all.map((u) => u.title), ['Achievement 11', 'Achievement 12']);
  });

  test(
    'profile uses the demo name and a drawn avatar, not the real site',
    () async {
      final pic = await service.getUserPicPath();
      expect(pic, '/UserPic/Demo.png');
      final res = await MockClient(
        ra.handle,
      ).get(Uri.parse('https://media.retroachievements.org$pic'));
      expect(res.bodyBytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
      expect(artworkRequests, isEmpty);
    },
  );

  test('game artwork is fetched from the real site', () async {
    await MockClient(
      ra.handle,
    ).get(Uri.parse('https://retroachievements.org/Images/1.png'));
    expect(artworkRequests.single.path, '/Images/1.png');
  });

  test('want to play and rescans answer without real data', () async {
    expect(await service.getUserWantToPlayList(), {2});
    expect(await service.getGameIdByHash('abc'), isNull);
    expect(await service.getGameList(5), isEmpty);
  });
}
