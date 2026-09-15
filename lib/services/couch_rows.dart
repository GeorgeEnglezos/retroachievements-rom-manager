import '../models/rom_result.dart';

/// One labelled shelf of games for a big-picture content tab.
typedef CouchRow = ({String title, List<RomResult> games});

/// Play Next's shelves: one row per console, plus a merged "All Consoles" row.
/// Every row is ordered hottest-first (most casual players). Games with no
/// console name collect under "Other".
({List<CouchRow> consoles, CouchRow overall}) playNextRows(
    List<RomResult> games) {
  final byName = <String, List<RomResult>>{};
  for (final g in games) {
    final name = (g.consoleName == null || g.consoleName!.isEmpty)
        ? 'Other'
        : g.consoleName!;
    (byName[name] ??= []).add(g);
  }
  for (final list in byName.values) {
    list.sort(_hottest);
  }
  final names = byName.keys.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final overall = [...games]..sort(_hottest);
  return (
    consoles: [for (final n in names) (title: n, games: byName[n]!)],
    overall: (title: 'All Consoles', games: overall),
  );
}

// Most casual players first.
int _hottest(RomResult a, RomResult b) =>
    (b.numPlayersCasual ?? 0).compareTo(a.numPlayersCasual ?? 0);
