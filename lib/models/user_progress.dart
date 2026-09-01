import '../services/ra_service.dart' show Achievement, RaAward, raAwardByName;

/// A user's achievement progress for one game. Persisted inside a system file
/// (see [GameEntry]); also returned live from the RA API.
class UserProgress {
  final int gameId;
  final int earnedAchievements;
  final int earnedHardcore;
  final DateTime? lastPlayed;
  // Highest RA award (beaten/completed/mastered) and when it was earned.
  final RaAward highestAward;
  final DateTime? highestAwardDate;
  final List<Achievement> achievements;

  UserProgress({
    required this.gameId,
    required this.earnedAchievements,
    required this.earnedHardcore,
    this.lastPlayed,
    this.highestAward = RaAward.none,
    this.highestAwardDate,
    this.achievements = const [],
  });

  factory UserProgress.fromJson(Map<String, dynamic> j) => UserProgress(
        gameId: (j['gameId'] as num?)?.toInt() ?? 0,
        earnedAchievements: (j['earnedAchievements'] as num?)?.toInt() ?? 0,
        earnedHardcore: (j['earnedHardcore'] as num?)?.toInt() ?? 0,
        lastPlayed: j['lastPlayed'] == null
            ? null
            : DateTime.tryParse(j['lastPlayed'] as String),
        highestAward: raAwardByName(j['highestAward'] as String?),
        highestAwardDate: j['highestAwardDate'] == null
            ? null
            : DateTime.tryParse(j['highestAwardDate'] as String),
        achievements: (j['achievements'] as List<dynamic>?)
                ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'earnedAchievements': earnedAchievements,
        'earnedHardcore': earnedHardcore,
        'lastPlayed': lastPlayed?.toIso8601String(),
        'highestAward': highestAward.name,
        'highestAwardDate': highestAwardDate?.toIso8601String(),
        'achievements': achievements.map((a) => a.toJson()).toList(),
      };
}
