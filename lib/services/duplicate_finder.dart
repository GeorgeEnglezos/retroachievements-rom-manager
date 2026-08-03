import 'package:path/path.dart' as p;
import '../models/rom_result.dart';
import 'disc_grouping.dart';

// Tokens marking a parenthetical as droppable noise before name comparison.
const _regionTokens = {
  'usa', 'europe', 'japan', 'world', 'asia', 'australia', 'korea', 'china',
  'france', 'germany', 'spain', 'italy', 'netherlands', 'sweden', 'brazil',
  'en', 'fr', 'de', 'es', 'it', 'nl', 'sv', 'pt', 'ja', 'ko', 'zh', 'ru',
  'u', 'e', 'j', 'unl', 'proto', 'beta', 'demo', 'sample',
};

// Disc/side parentheticals are kept so multi-disc games don't merge.
final _discMarker = RegExp(r'\b(disc|disk|cd|side|tape|part)\b\s*\d*[a-z]?',
    caseSensitive: false);

// Revision / version tags like "rev 1", "v1.1", "ver 2".
final _revMarker = RegExp(r'^(rev|v|ver|version)[\s.]?\d', caseSensitive: false);

// True when a (...)/[...] group is pure noise; disc markers are kept.
bool _isNoiseTag(String inner) {
  final lower = inner.toLowerCase().trim();
  if (lower.isEmpty) return true;
  if (_discMarker.hasMatch(lower)) return false; // keep disc markers
  if (_revMarker.hasMatch(lower)) return true;
  if (lower.length <= 3 && RegExp(r'^[a-z!0-9 ]+$').hasMatch(lower)) {
    return true; // short dump flags like "!", "b", "h1"
  }
  // Split on commas/spaces; noise if every token is a known region/lang token.
  final tokens = lower.split(RegExp(r'[,\s]+')).where((t) => t.isNotEmpty);
  return tokens.isNotEmpty && tokens.every(_regionTokens.contains);
}

/// Filename -> comparison key: drop extension + noise tags, sort words.
// Same word multiset collides; accepted since gameId is the
// primary link.
String normalizeGameName(String fileName) {
  var name = p.basenameWithoutExtension(fileName);

  // Drop noise groups, keep disc markers inline.
  final buffer = StringBuffer();
  final tagRe = RegExp(r'[\(\[]([^\)\]]*)[\)\]]');
  var last = 0;
  for (final m in tagRe.allMatches(name)) {
    buffer.write(name.substring(last, m.start));
    final inner = m.group(1) ?? '';
    if (!_isNoiseTag(inner)) buffer.write(' $inner ');
    last = m.end;
  }
  buffer.write(name.substring(last));
  name = buffer.toString().toLowerCase();

  // Replace all punctuation with spaces, split, sort words, rejoin.
  final words = name
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList()
    ..sort();
  return words.join(' ');
}

/// Groups same-game ROMs (shared gameId OR normalized name, transitive via
/// union-find). Singleton groups stay null. Mutates in place.
void assignDuplicateGroups(List<RomResult> roms) {
  final parent = List<int>.generate(roms.length, (i) => i);

  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) => parent[find(a)] = find(b);

  // Link by gameId + disc number: all discs of a multi-disc game share one
  // gameId, so keying on gameId alone flags Disc 1 and Disc 2 as duplicates.
  // Only the same disc of the same game (or a single-disc game) unions here.
  final byGameId = <String, int>{};
  for (var i = 0; i < roms.length; i++) {
    final id = roms[i].gameId;
    if (id == null) continue;
    final key = '$id#${discNumber(roms[i].fileName) ?? ''}';
    final seen = byGameId[key];
    if (seen != null) union(i, seen);
    byGameId[key] = i;
  }

  // Link by normalized name.
  final byName = <String, int>{};
  for (var i = 0; i < roms.length; i++) {
    final key = normalizeGameName(roms[i].fileName);
    if (key.isEmpty) continue;
    final seen = byName[key];
    if (seen != null) union(i, seen);
    byName[key] = i;
  }

  // Count members per root; only roots with >=2 become real groups.
  final members = <int, List<int>>{};
  for (var i = 0; i < roms.length; i++) {
    members.putIfAbsent(find(i), () => []).add(i);
  }

  var nextGroupId = 0;
  for (final entry in members.entries) {
    if (entry.value.length < 2) {
      for (final i in entry.value) {
        roms[i].duplicateGroupId = null;
      }
      continue;
    }
    final gid = nextGroupId++;
    for (final i in entry.value) {
      roms[i].duplicateGroupId = gid;
    }
  }
}

