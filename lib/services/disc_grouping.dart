import 'package:path/path.dart' as p;

import '../models/rom_result.dart';

/// One listing entry: either a single ROM or a multi-disc set (2+ discs of the
/// same game). [discs] is sorted by disc number; length is always >= 1.
class DiscGroup {
  final List<RomResult> discs;
  const DiscGroup(this.discs);

  bool get isMultiDisc => discs.length > 1;

  /// Prefer a matched disc so the row shows box art; else the first disc.
  RomResult get representative => discs.firstWhere(
        (r) => r.status == RomStatus.supported,
        orElse: () => discs.first,
      );

  int get totalSize => discs.fold(0, (sum, r) => sum + (r.fileSize ?? 0));
}

// (Disc 1) / (Disc 2 of 3) / [Disk 2] / (CD1) / (CD-2), Redump/No-Intro style.
// Requires digits right after disc/disk/cd so "Disco Volante" doesn't match.
final _discToken = RegExp(
  r'\s*[\(\[]\s*(?:dis[ck]|cd)\s*-?\s*(\d+)(?:\s*of\s*\d+)?\s*[\)\]]',
  caseSensitive: false,
);

/// The disc number in [fileName], or null if it carries no disc token.
int? discNumber(String fileName) {
  final m = _discToken.firstMatch(fileName);
  return m == null ? null : int.parse(m.group(1)!);
}

/// [fileName] with its disc token removed (extension kept). Used for the group
/// title and to match sibling discs.
String stripDiscToken(String fileName) => fileName
    .replaceFirst(_discToken, '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// dir + normalized base (token stripped); two files group only when both match.
String? _groupKey(String filePath) {
  final name = p.basename(filePath);
  if (discNumber(name) == null) return null;
  return '${p.dirname(filePath).toLowerCase()}|'
      '${stripDiscToken(name).toLowerCase()}';
}

/// Collapses multi-disc sets in [roms] into single [DiscGroup]s, preserving the
/// input order (a set appears at its first disc's position). Files with no disc
/// token, or a lone disc with no siblings, stay as singleton groups.
List<DiscGroup> groupDiscs(List<RomResult> roms) {
  final buckets = <String, List<RomResult>>{};
  for (final r in roms) {
    final key = _groupKey(r.filePath);
    if (key != null) buckets.putIfAbsent(key, () => []).add(r);
  }
  final multi = {
    for (final e in buckets.entries)
      if (e.value.length > 1) e.key,
  };
  final emitted = <String>{};
  final out = <DiscGroup>[];
  for (final r in roms) {
    final key = _groupKey(r.filePath);
    if (key != null && multi.contains(key)) {
      if (emitted.add(key)) {
        final members = [...buckets[key]!]
          ..sort((a, b) => (discNumber(a.fileName) ?? 0)
              .compareTo(discNumber(b.fileName) ?? 0));
        out.add(DiscGroup(members));
      }
    } else {
      out.add(DiscGroup([r]));
    }
  }
  return out;
}
