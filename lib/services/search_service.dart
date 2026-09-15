import '../models/home_index.dart';
import '../models/rom_result.dart';
import 'console_map.dart';

/// One search result: a [RomResult] built from the home index row (enough to
/// render a row identical to the folder listing) plus the system it lives in.
/// [systemPath] lets the detail dialog load the system file for full game info
/// on tap. Built by the home screen from the home index search rows.
class SearchHit {
  final String systemName;
  final String systemPath;
  final RomResult rom;

  const SearchHit({
    required this.systemName,
    required this.systemPath,
    required this.rom,
  });
}

/// Filters the home-index [rows] for [query] (case-insensitive match on title
/// or file name), drops rows containing any [excludeTerms] (already
/// lowercased), and returns hits sorted by system name. Rows from a missing
/// system never reach here: the index itself leaves them out.
List<SearchHit> buildSearchHits(
  List<SearchIndexEntry> rows,
  String query, {
  List<String> excludeTerms = const [],
}) {
  final q = query.toLowerCase();
  final hits = <SearchHit>[];
  for (final r in rows) {
    final titleMatch = r.title?.toLowerCase().contains(q) ?? false;
    final fileMatch = r.fileName.toLowerCase().contains(q);
    if (!titleMatch && !fileMatch) continue;
    if (excludeTerms.isNotEmpty) {
      final haystack = '${r.fileName} ${r.title ?? ''}'.toLowerCase();
      if (excludeTerms.any(haystack.contains)) continue;
    }
    final rom = RomResult(filePath: r.filePath, fileName: r.fileName)
      ..md5Hash = r.md5
      ..gameId = r.gameId
      ..gameTitle = r.title
      ..imageIcon = r.icon
      ..earnedAchievements = r.earnedAchievements
      ..achievementCount = r.achievementCount
      ..status = r.matched
          ? RomStatus.supported
          : (r.noMatch ? RomStatus.unsupported : RomStatus.notFetched);
    hits.add(SearchHit(
      systemName: r.systemName,
      systemPath: r.systemPath,
      rom: rom,
    ));
  }
  hits.sort((a, b) =>
      a.systemName.toLowerCase().compareTo(b.systemName.toLowerCase()));
  return hits;
}

/// Systems whose folder name (short) or console name (long) contains [query],
/// case-insensitive. Lets a search like "gba" surface the Game Boy Advance
/// folder to open, reusing the short/long names the app already has.
List<SystemSummary> matchFolders(List<SystemSummary> systems, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final s in systems)
      if (s.name.toLowerCase().contains(q) ||
          (ConsoleMap.nameFor(s.consoleId)?.toLowerCase().contains(q) ?? false))
        s,
  ];
}
