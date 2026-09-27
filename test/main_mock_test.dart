import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/demo/main_mock.dart';

// The screenshot launcher must never put the real name on screen or show
// another maker's unlocks; these pin that down against a fake RA.
void main() {
  late List<Uri> sent;
  late MockClient client;

  setUp(() {
    sent = [];
    final ra = MockClient((req) async {
      sent.add(req.url);
      final body = switch (req.url.path) {
        '/API/API_GetUserProfile.php' => {
          'User': 'RealName',
          'UserPic': '/UserPic/RealName.png',
        },
        '/API/API_GetAchievementsEarnedBetween.php' => [
          {'Title': 'Sony one', 'ConsoleName': 'PlayStation 2'},
          {'Title': 'Other one', 'ConsoleName': 'Game Boy Advance'},
        ],
        '/API/API_GetUserCompletionProgress.php' => {
          'Total': 2,
          'Results': [
            {'GameID': 1, 'ConsoleName': 'PlayStation Portable'},
            {'GameID': 2, 'ConsoleName': 'Nintendo DS'},
          ],
        },
        _ => {'ok': true},
      };
      return http.Response(jsonEncode(body), 200);
    });
    client = MockClient(aliasedRa(network: ra, realName: 'RealName'));
  });

  Uri api(String path) => Uri.https('retroachievements.org', path, {
    'z': fakeName,
    'y': 'key',
    'u': fakeName,
  });

  test('asks RA as the real user', () async {
    await client.get(api('/API/API_GetGameInfoAndUserProgress.php'));
    expect(sent.single.queryParameters['u'], 'RealName');
    expect(sent.single.queryParameters['z'], 'RealName');
  });

  test('profile shows the fake name and a drawn avatar', () async {
    final res = await client.get(api('/API/API_GetUserProfile.php'));
    expect(res.body, isNot(contains('RealName')));
    final pic = jsonDecode(res.body)['UserPic'] as String;
    final avatar = await client.get(
      Uri.parse('https://media.retroachievements.org$pic'),
    );
    expect(avatar.bodyBytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
    expect(sent.where((u) => u.path.startsWith('/UserPic/')), isEmpty);
  });

  test('unlocks and completion keep only the shown maker', () async {
    final unlocks = jsonDecode(
      (await client.get(api('/API/API_GetAchievementsEarnedBetween.php'))).body,
    );
    expect([for (final u in unlocks) u['Title']], ['Sony one']);
    final done = jsonDecode(
      (await client.get(api('/API/API_GetUserCompletionProgress.php'))).body,
    );
    expect([for (final g in done['Results']) g['GameID']], [1]);
  });
}
