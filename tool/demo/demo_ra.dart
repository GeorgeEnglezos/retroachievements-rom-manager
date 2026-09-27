import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// A stand-in for retroachievements.org's API, answered from the snapshot
/// `export_demo_data.dart` took of your real library, under a demo username.
/// Artwork requests go to [artwork] (the real site); only the avatar is drawn,
/// since the demo user has none.
class DemoRa {
  final String username;
  final List<int> wantToPlay;
  final http.Client artwork;

  /// gameId -> stored library entry (gameInfo, progress, file details).
  final Map<int, Map<String, dynamic>> games = {};

  DemoRa(Map<String, dynamic> data, {required this.artwork})
    : username = data['username'] as String,
      wantToPlay = (data['wantToPlay'] as List).cast<int>() {
    for (final s in (data['systems'] as List).cast<Map<String, dynamic>>()) {
      for (final g in (s['games'] as List).cast<Map<String, dynamic>>()) {
        if (g['matched'] == true &&
            g['gameId'] is int &&
            g['gameInfo'] != null) {
          games.putIfAbsent(g['gameId'] as int, () => g);
        }
      }
    }
  }

  Future<http.Response> handle(http.Request req) async {
    final q = req.url.queryParameters;
    switch (req.url.path) {
      case '/API/API_GetUserProfile.php':
        return _json({'User': username, 'UserPic': '/UserPic/$username.png'});
      case '/API/API_GetGameInfoAndUserProgress.php':
        final g = games[int.parse(q['g']!)];
        return g == null ? http.Response('{}', 404) : _json(_gameInfo(g));
      case '/API/API_GetUserCompletionProgress.php':
        final played = [
          for (final g in games.values)
            if (_earned(g) > 0) _completion(g),
        ];
        return _json({
          'Count': played.length,
          'Total': played.length,
          'Results': played,
        });
      case '/API/API_GetUserWantToPlayList.php':
        return _json({
          'Count': wantToPlay.length,
          'Total': wantToPlay.length,
          'Results': [
            for (final id in wantToPlay) {'ID': id},
          ],
        });
      case '/API/API_GetAchievementsEarnedBetween.php':
        return _json(_earnedBetween(int.parse(q['f']!), int.parse(q['t']!)));
      // The library is seeded already scanned, so a rescan (which only
      // happens if you run one) finds nothing new rather than real data.
      case '/API/API_GetGameList.php':
        return _json(const []);
      case '/dorequest.php':
        return _json({'Success': true, 'GameID': 0});
    }
    if (req.url.path.startsWith('/UserPic/')) {
      return http.Response.bytes(
        _avatar(),
        200,
        headers: {'content-type': 'image/png'},
      );
    }
    if (req.url.host.endsWith('retroachievements.org')) {
      return artwork.get(req.url);
    }
    // Anything else (the GitHub update check) just finds nothing.
    return http.Response('', 404);
  }

  static Map<String, dynamic> _info(Map<String, dynamic> g) =>
      g['gameInfo'] as Map<String, dynamic>;
  static Map<String, dynamic> _progress(Map<String, dynamic> g) =>
      g['progress'] as Map<String, dynamic>? ?? const {};
  static int _earned(Map<String, dynamic> g) =>
      (_progress(g)['earnedAchievements'] as num?)?.toInt() ?? 0;

  /// The stored [RaAward] name as RA's `HighestAwardKind`.
  static String? _kind(String? award) => switch (award) {
    'beatenSoftcore' => 'beaten-softcore',
    'beatenHardcore' => 'beaten-hardcore',
    'completed' => 'completed',
    'mastered' => 'mastered',
    _ => null,
  };

  /// Stored achievements already use RA's field names (Achievement.toJson).
  static List<Map<String, dynamic>> _achievements(Map<String, dynamic> g) =>
      (_progress(g)['achievements'] as List? ?? const [])
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> _gameInfo(Map<String, dynamic> g) {
    final info = _info(g);
    final progress = _progress(g);
    return {
      'ID': info['gameId'],
      'Title': info['title'],
      'ConsoleID': info['consoleId'],
      'ConsoleName': info['consoleName'],
      'NumAchievements': info['achievementCount'],
      'ImageIcon': info['imageIcon'],
      'ImageBoxArt': info['imageBoxArt'],
      'ImageTitle': info['imageTitle'],
      'ImageIngame': info['imageIngame'],
      'Publisher': info['publisher'],
      'Developer': info['developer'],
      'Genre': info['genre'],
      'Released': info['released'],
      'NumDistinctPlayersCasual': info['numPlayersCasual'],
      'NumAwardedToUser': progress['earnedAchievements'] ?? 0,
      'NumAwardedToUserHardcore': progress['earnedHardcore'] ?? 0,
      'HighestAwardKind': _kind(progress['highestAward'] as String?),
      'HighestAwardDate': progress['highestAwardDate'],
      'Achievements': {
        for (final a in _achievements(g))
          '${a['ID']}': {
            ...a,
            // RA's set-date fields; the app derives set created/updated here.
            'DateCreated': info['setCreated'],
            'DateModified': info['setUpdated'],
          },
      },
    };
  }

  Map<String, dynamic> _completion(Map<String, dynamic> g) {
    final info = _info(g);
    final progress = _progress(g);
    return {
      'GameID': info['gameId'],
      'Title': info['title'],
      'ConsoleName': info['consoleName'],
      'ConsoleID': info['consoleId'],
      'ImageIcon': info['imageIcon'],
      'MaxPossible': info['achievementCount'],
      'NumAwarded': progress['earnedAchievements'],
      'NumAwardedHardcore': progress['earnedHardcore'] ?? 0,
      'MostRecentAwardedDate': progress['lastPlayed'],
      'HighestAwardKind': _kind(progress['highestAward'] as String?),
      'HighestAwardDate': progress['highestAwardDate'],
    };
  }

  /// Unlocks between two unix timestamps, oldest first like RA.
  List<Map<String, dynamic>> _earnedBetween(int from, int to) {
    final out = <Map<String, dynamic>>[];
    for (final g in games.values) {
      for (final a in _achievements(g)) {
        final date = DateTime.tryParse(a['DateEarned'] as String? ?? '');
        if (date == null) continue;
        final s = date.millisecondsSinceEpoch ~/ 1000;
        if (s < from || s > to) continue;
        out.add({
          'Date': a['DateEarned'],
          'HardcoreMode': a['DateEarnedHardcore'] != null ? 1 : 0,
          'Title': a['Title'],
          'Description': a['Description'],
          'BadgeName': a['BadgeName'],
          'Points': a['Points'],
          'GameTitle': _info(g)['title'],
          'GameID': _info(g)['gameId'],
        });
      }
    }
    out.sort((a, b) => (a['Date'] as String).compareTo(b['Date'] as String));
    return out;
  }

  /// Plain initial-on-colour avatar for the demo user.
  Uint8List _avatar() {
    final image = img.Image(width: 128, height: 128);
    img.fill(image, color: img.ColorRgb8(0x3B, 0x6E, 0xA8));
    img.drawString(
      image,
      username[0],
      font: img.arial48,
      x: 50,
      y: 38,
      color: img.ColorRgb8(255, 255, 255),
    );
    return img.encodePng(image);
  }

  static http.Response _json(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
