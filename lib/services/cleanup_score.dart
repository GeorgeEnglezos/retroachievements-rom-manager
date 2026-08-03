import 'dart:math' as math;

/// How a game's cleanup score is computed. Lower score = more deletable.
enum CleanupScoreMode {
  /// players / log2(ageMonths + 2), log-dampened because most players arrive
  /// in a set's first months.
  logDampened,

  /// players / ageYears, the set's observed players-per-year rate. The user's
  /// target ratio is shown as a reference; it does not change the ordering.
  ratio,
}

String cleanupModeLabel(CleanupScoreMode m) => switch (m) {
      CleanupScoreMode.logDampened => 'Log-dampened',
      CleanupScoreMode.ratio => 'Players / year',
    };

/// Sets younger than this are too new to judge and score as null.
const cleanupGraceMonths = 6.0;

const _daysPerMonth = 30.44;

/// Cleanup score for one game, or null when it can't be judged: no set-creation
/// date (achievements not fetched / unmatched) or younger than the grace
/// period. Lower = more deletable, so callers sort ascending. Pure; `now`
/// injectable for tests.
double? cleanupScore({
  required int players,
  required DateTime? setCreated,
  required CleanupScoreMode mode,
  DateTime? now,
}) {
  if (setCreated == null) return null;
  final today = now ?? DateTime.now();
  final ageMonths = today.difference(setCreated).inDays / _daysPerMonth;
  if (ageMonths < cleanupGraceMonths) return null;
  switch (mode) {
    case CleanupScoreMode.logDampened:
      // +2 keeps the divisor >= 1 so young sets' scores aren't inflated.
      return players / (math.log(ageMonths + 2) / math.ln2);
    case CleanupScoreMode.ratio:
      return players / (ageMonths / 12);
  }
}
