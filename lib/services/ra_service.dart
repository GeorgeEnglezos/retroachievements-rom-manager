import 'dart:convert';
import 'package:http/http.dart' as http;
import 'http_throttle.dart';
import 'log_service.dart';
import '../models/user_progress.dart';

class Achievement {
  final int id;
  final String title;
  final String description;
  final int points;
  // RA "RetroPoints": rarity-weighted score, our effort-to-master proxy.
  final int trueRatio;
  final String badgeName;
  final int displayOrder;
  final int numAwarded;
  final DateTime? dateEarned;
  final DateTime? dateEarnedHardcore;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    this.trueRatio = 0,
    required this.badgeName,
    required this.displayOrder,
    required this.numAwarded,
    this.dateEarned,
    this.dateEarnedHardcore,
  });

  bool get isEarned => dateEarned != null;

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id: (j['ID'] as num?)?.toInt() ?? 0,
        title: j['Title'] as String? ?? '',
        description: j['Description'] as String? ?? '',
        points: (j['Points'] as num?)?.toInt() ?? 0,
        trueRatio: (j['TrueRatio'] as num?)?.toInt() ?? 0,
        badgeName: j['BadgeName'] as String? ?? '',
        displayOrder: (j['DisplayOrder'] as num?)?.toInt() ?? 0,
        numAwarded: (j['NumAwarded'] as num?)?.toInt() ?? 0,
        dateEarned: _parseDate(j['DateEarned'] as String?),
        dateEarnedHardcore: _parseDate(j['DateEarnedHardcore'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'ID': id,
        'Title': title,
        'Description': description,
        'Points': points,
        'TrueRatio': trueRatio,
        'BadgeName': badgeName,
        'DisplayOrder': displayOrder,
        'NumAwarded': numAwarded,
        'DateEarned': dateEarned?.toIso8601String(),
        'DateEarnedHardcore': dateEarnedHardcore?.toIso8601String(),
      };

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class GameInfo {
  final int gameId;
  final String title;
  final String consoleName;
  final int? consoleId;
  final int achievementCount;
  final String? imageIcon;
  final String? imageBoxArt;
  final String? imageTitle; // RA title-screen screenshot path
  final String? imageIngame; // RA in-game screenshot path
  final String? publisher;
  final String? developer;
  final String? genre;
  final String? released;
  // Earliest achievement creation date ≈ when the achievement set was released.
  final DateTime? setCreated;
  // Latest achievement modification date ≈ when the set was last revised.
  final DateTime? setUpdated;
  // Sum of achievement points; null without data (RA has no total field).
  final int? points;
  final int numPlayersCasual;
  final int numPlayersHardcore;

  GameInfo({
    required this.gameId,
    required this.title,
    required this.consoleName,
    this.consoleId,
    required this.achievementCount,
    this.imageIcon,
    this.imageBoxArt,
    this.imageTitle,
    this.imageIngame,
    this.publisher,
    this.developer,
    this.genre,
    this.released,
    this.setCreated,
    this.setUpdated,
    this.points,
    this.numPlayersCasual = 0,
    this.numPlayersHardcore = 0,
  });

  factory GameInfo.fromJson(Map<String, dynamic> j) => GameInfo(
        gameId: (j['gameId'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        consoleName: j['consoleName'] as String? ?? '',
        consoleId: (j['consoleId'] as num?)?.toInt(),
        achievementCount: (j['achievementCount'] as num?)?.toInt() ?? 0,
        imageIcon: j['imageIcon'] as String?,
        imageBoxArt: j['imageBoxArt'] as String?,
        imageTitle: j['imageTitle'] as String?,
        imageIngame: j['imageIngame'] as String?,
        publisher: j['publisher'] as String?,
        developer: j['developer'] as String?,
        genre: j['genre'] as String?,
        released: j['released'] as String?,
        setCreated: j['setCreated'] != null
            ? DateTime.tryParse(j['setCreated'] as String)
            : null,
        setUpdated: j['setUpdated'] != null
            ? DateTime.tryParse(j['setUpdated'] as String)
            : null,
        points: (j['points'] as num?)?.toInt(),
        numPlayersCasual: (j['numPlayersCasual'] as num?)?.toInt() ?? 0,
        numPlayersHardcore: (j['numPlayersHardcore'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'title': title,
        'consoleName': consoleName,
        'consoleId': consoleId,
        'achievementCount': achievementCount,
        'imageIcon': imageIcon,
        'imageBoxArt': imageBoxArt,
        'imageTitle': imageTitle,
        'imageIngame': imageIngame,
        'publisher': publisher,
        'developer': developer,
        'genre': genre,
        'released': released,
        'setCreated': setCreated?.toIso8601String(),
        'setUpdated': setUpdated?.toIso8601String(),
        'points': points,
        'numPlayersCasual': numPlayersCasual,
        'numPlayersHardcore': numPlayersHardcore,
      };
}

/// One game from the RA completion-progress endpoint.
class CompletedGame {
  final int gameId;
  final String title;
  final String consoleName;
  final int numAwarded;
  final int numAwardedHardcore;
  final int maxPossible;
  final String? imageIcon;
  final DateTime? lastPlayed;

  CompletedGame({
    required this.gameId,
    required this.title,
    required this.consoleName,
    required this.numAwarded,
    this.numAwardedHardcore = 0,
    required this.maxPossible,
    this.imageIcon,
    this.lastPlayed,
  });

  factory CompletedGame.fromJson(Map<String, dynamic> j) => CompletedGame(
        gameId: (j['GameID'] as num?)?.toInt() ?? 0,
        title: j['Title'] as String? ?? 'Unknown',
        consoleName: j['ConsoleName'] as String? ?? 'Unknown',
        numAwarded: (j['NumAwarded'] as num?)?.toInt() ?? 0,
        maxPossible: (j['MaxPossible'] as num?)?.toInt() ?? 0,
        imageIcon: (j['ImageIcon'] as String?)?.isEmpty ?? true
            ? null
            : j['ImageIcon'] as String?,
        numAwardedHardcore: (j['NumAwardedHardcore'] as num?)?.toInt() ?? 0,
        lastPlayed: (j['MostRecentAwardedDate'] as String?)?.isNotEmpty ?? false
            ? DateTime.tryParse(j['MostRecentAwardedDate'] as String)
            : null,
      );
}

/// One game from `API_GetGameList`: enough for offline matching + basic rows.
class RaGameListEntry {
  final int gameId;
  final String title;
  final int? consoleId;
  final String? imageIcon;
  final int achievementCount;
  final int? points;
  final DateTime? dateModified;
  final List<String> hashes; // lowercased md5s

  RaGameListEntry({
    required this.gameId,
    required this.title,
    this.consoleId,
    this.imageIcon,
    this.achievementCount = 0,
    this.points,
    this.dateModified,
    this.hashes = const [],
  });

  RaGameListEntry copyWith({List<String>? hashes}) => RaGameListEntry(
        gameId: gameId,
        title: title,
        consoleId: consoleId,
        imageIcon: imageIcon,
        achievementCount: achievementCount,
        points: points,
        dateModified: dateModified,
        hashes: hashes ?? this.hashes,
      );

  factory RaGameListEntry.fromJson(Map<String, dynamic> j) => RaGameListEntry(
        gameId: (j['ID'] as num?)?.toInt() ?? 0,
        title: j['Title'] as String? ?? '',
        consoleId: (j['ConsoleID'] as num?)?.toInt(),
        imageIcon: j['ImageIcon'] as String?,
        achievementCount: (j['NumAchievements'] as num?)?.toInt() ?? 0,
        points: (j['Points'] as num?)?.toInt(),
        dateModified: _parseDate(j['DateModified'] as String?),
        hashes: [
          for (final h in (j['Hashes'] ?? const []) as List)
            (h as String).toLowerCase(),
        ],
      );

  Map<String, dynamic> toJson() => {
        'ID': gameId,
        'Title': title,
        'ConsoleID': consoleId,
        'ImageIcon': imageIcon,
        'NumAchievements': achievementCount,
        'Points': points,
        'DateModified': dateModified?.toIso8601String(),
        'Hashes': hashes,
      };

  static DateTime? _parseDate(String? s) =>
      (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
}

class RaService {
  final String username;
  final String apiKey;

  // Throttled GET behind every call: 350ms gap, 4 retries on 429, RA User-Agent.
  // Injectable so tests can drive the network path with a fake client.
  final HttpThrottle _throttle;

  RaService({
    required this.username,
    required this.apiKey,
    HttpThrottle? throttle,
  }) : _throttle = throttle ??
            HttpThrottle(headers: const {'User-Agent': 'RAROMManager/1.0'});

  Future<http.Response> _get(Uri uri, {Duration? timeout}) =>
      _throttle.get(uri, timeout: timeout);

  /// List endpoints ship megabytes (a console's whole game list, the paginated
  /// completion sweep), so they get far longer than a per-ROM lookup before the
  /// request is called dead.
  static const _listTimeout = Duration(minutes: 3);

  /// RA's canonical avatar path (`/UserPic/Name.png`) for this user. The media
  /// host is case-sensitive, so this authoritative path, not one built from the
  /// typed username, is what the avatar URL must use.
  Future<String> getUserPicPath() async {
    // 'y' is the API key, and it is in the URI of every request below. Never
    // log a request URI from here or from http_throttle.dart without redacting
    // it first; error paths deliberately log response bodies instead.
    final uri =
        Uri.https('retroachievements.org', '/API/API_GetUserProfile.php', {
      'z': username,
      'y': apiKey,
      'u': username,
    });
    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pic = data['UserPic'];
    if (pic is! String || pic.isEmpty) {
      throw Exception('profile has no UserPic');
    }
    return pic;
  }

  /// Every achievement-having game for [consoleId], with its hashes, in one
  /// call. `h=1` includes hashes; `f=1` limits to games that have achievements.
  Future<List<RaGameListEntry>> getGameList(int consoleId) async {
    final uri = Uri.https('retroachievements.org', '/API/API_GetGameList.php', {
      'z': username,
      'y': apiKey,
      'i': '$consoleId',
      'h': '1',
      'f': '1',
    });
    final response = await _get(uri, timeout: _listTimeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return parseGameList(jsonDecode(response.body));
  }

  /// Hash -> gameId via `dorequest`: resolves ANY hash RA knows (GetGameList
  /// omits secondary dumps). Null when RA has no match.
  Future<int?> getGameIdByHash(String md5Hash) async {
    final uri = Uri.https('retroachievements.org', '/dorequest.php', {
      'r': 'gameid',
      'm': md5Hash,
    });
    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['GameID'];
    if (id is int && id > 0) return id;
    if (id is String) {
      final parsed = int.tryParse(id);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  /// Every game with earned achievements; paginated 500 at a time.
  Future<List<CompletedGame>> getUserCompletionProgress() async {
    final all = <CompletedGame>[];
    const pageSize = 500;
    var offset = 0;
    while (true) {
      final uri = Uri.https(
        'retroachievements.org',
        '/API/API_GetUserCompletionProgress.php',
        {
          'z': username,
          'y': apiKey,
          'u': username,
          'c': '$pageSize',
          'o': '$offset',
        },
      );
      final response = await _get(uri, timeout: _listTimeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final page = parseCompletionProgress(data);
      all.addAll(page);
      final total = (data['Total'] as num?)?.toInt() ?? all.length;
      offset += pageSize;
      if (page.isEmpty || all.length >= total) break;
    }
    return all;
  }

  static List<CompletedGame> parseCompletionProgress(
      Map<String, dynamic> data) {
    final results = data['Results'];
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map) CompletedGame.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  static List<RaGameListEntry> parseGameList(dynamic results) {
    if (results is! List) return const [];
    return [
      for (final r in results)
        if (r is Map) RaGameListEntry.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  Future<(GameInfo, UserProgress)> getGameInfoAndUserProgress(int gameId) async {
    final uri = Uri.https(
        'retroachievements.org',
        '/API/API_GetGameInfoAndUserProgress.php',
        {'z': username, 'y': apiKey, 'u': username, 'g': gameId.toString()});
    final response = await _get(uri);
    if (response.statusCode != 200) {
      final body = response.body.length > 300
          ? response.body.substring(0, 300)
          : response.body;
      LogService.error('RaService/getGameInfoAndUserProgress',
          'HTTP ${response.statusCode} for game $gameId: $body');
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response (game $gameId returned ${decoded.runtimeType})');
    }
    return parseGameInfoAndProgress(gameId, decoded);
  }

  static (GameInfo, UserProgress) parseGameInfoAndProgress(
      int gameId, Map<String, dynamic> data) {
    int count = data['NumAchievements'] as int? ?? 0;
    if (count == 0) {
      final ach = data['Achievements'];
      if (ach is Map) count = ach.length;
    }

    String? str(String key) {
      final v = data[key];
      if (v == null || v == '') return null;
      return v.toString();
    }

    int asInt(String key) => (data[key] as num?)?.toInt() ?? 0;

    DateTime? lastPlayed;
    // RA has no set release/revision dates; earliest DateCreated and latest
    // DateModified are the proxies.
    DateTime? setCreated;
    DateTime? setUpdated;
    final achievementsList = <Achievement>[];
    final achievements = data['Achievements'];
    if (achievements is Map) {
      for (final ach in achievements.values) {
        if (ach is Map) {
          final dateStr = ach['DateEarned'] as String?;
          if (dateStr != null && dateStr.isNotEmpty) {
            final dt = DateTime.tryParse(dateStr);
            if (dt != null && (lastPlayed == null || dt.isAfter(lastPlayed))) {
              lastPlayed = dt;
            }
          }
          final createdStr = ach['DateCreated'] as String?;
          if (createdStr != null && createdStr.isNotEmpty) {
            final c = DateTime.tryParse(createdStr);
            if (c != null && (setCreated == null || c.isBefore(setCreated))) {
              setCreated = c;
            }
          }
          final modStr = ach['DateModified'] as String?;
          if (modStr != null && modStr.isNotEmpty) {
            final m = DateTime.tryParse(modStr);
            if (m != null && (setUpdated == null || m.isAfter(setUpdated))) {
              setUpdated = m;
            }
          }
          try {
            achievementsList
                .add(Achievement.fromJson(Map<String, dynamic>.from(ach)));
          } catch (_) {}
        }
      }
      achievementsList.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    final points = achievementsList.isEmpty
        ? null
        : achievementsList.fold<int>(0, (sum, a) => sum + a.points);

    final info = GameInfo(
      gameId: gameId,
      title: data['Title'] as String? ?? 'Unknown',
      consoleName: data['ConsoleName'] as String? ?? 'Unknown',
      consoleId: (data['ConsoleID'] as num?)?.toInt(),
      achievementCount: count,
      imageIcon: str('ImageIcon'),
      imageBoxArt: str('ImageBoxArt'),
      imageTitle: str('ImageTitle'),
      imageIngame: str('ImageIngame'),
      publisher: str('Publisher'),
      developer: str('Developer'),
      genre: str('Genre'),
      released: str('Released'),
      setCreated: setCreated,
      setUpdated: setUpdated,
      points: points,
      numPlayersCasual: asInt('NumDistinctPlayersCasual'),
      numPlayersHardcore: asInt('NumDistinctPlayersHardcore'),
    );

    final earnedCasual = (data['NumAwardedToUser'] as num?)?.toInt() ?? 0;
    final earnedHardcore =
        (data['NumAwardedToUserHardcore'] as num?)?.toInt() ?? 0;

    final progress = UserProgress(
      gameId: gameId,
      earnedAchievements: earnedCasual,
      earnedHardcore: earnedHardcore,
      lastPlayed: lastPlayed,
      achievements: achievementsList,
    );

    return (info, progress);
  }
}
