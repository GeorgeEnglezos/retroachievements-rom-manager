import 'ra_service.dart' show Achievement;

/// Effort-to-master proxy: summed TrueRatio of unearned achievements (RA has
/// no playtime). 0 when done or no TrueRatio data.
int masteryEffort(List<Achievement> achievements) {
  var sum = 0;
  for (final a in achievements) {
    if (!a.isEarned) sum += a.trueRatio;
  }
  return sum;
}
