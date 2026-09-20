import 'dart:math' as math;

/// Sets younger than this are too new to judge and score as null.
const leastPlayedGraceMonths = 6.0;

const _daysPerMonth = 30.44;

/// Least-played score for one game, or null when it can't be judged: no set-creation
/// date (achievements not fetched / unmatched) or younger than the grace
/// period. players / log2(ageMonths + 2), log-dampened because most players
/// arrive in a set's first months. Lower = more deletable, so callers sort
/// ascending. Pure; `now` injectable for tests.
double? leastPlayedScore({
  required int players,
  required DateTime? setCreated,
  DateTime? now,
}) {
  if (setCreated == null) return null;
  final today = now ?? DateTime.now();
  final ageMonths = today.difference(setCreated).inDays / _daysPerMonth;
  if (ageMonths < leastPlayedGraceMonths) return null;
  // +2 keeps the divisor >= 1 so young sets' scores aren't inflated.
  return players / (math.log(ageMonths + 2) / math.ln2);
}
