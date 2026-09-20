import 'package:path/path.dart' as p;

import '../models/rom_result.dart';
import 'switch_grouping.dart';

/// One listing entry: a single ROM, a multi-disc set (2+ discs of the same
/// game), or the files of one Switch title. [discs] is sorted by disc number
/// (or by part, for a Switch title); length is always >= 1.
class DiscGroup {
  final List<RomResult> discs;

  /// True when [discs] are the parts of one Switch title (base + updates +
  /// DLC) rather than discs of one game. They are not interchangeable: only
  /// the base part boots.
  final bool switchTitle;

  const DiscGroup(this.discs, {this.switchTitle = false});

  bool get isMultiDisc => discs.length > 1;

  /// Prefer a matched disc so the row shows box art; else the first disc. A
  /// Switch title always leads with its base part, the only bootable file, so
  /// the row's play/launch path targets something that runs.
  RomResult get representative => switchTitle
      ? discs.first
      : discs.firstWhere(
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

// dir + normalized base (token stripped), or dir + masked Switch title id; two
// files group only when both match. Null when the file joins no group.
({String key, bool switchTitle})? _groupKey(String filePath) {
  final name = p.basename(filePath);
  final dir = p.dirname(filePath).toLowerCase();
  if (discNumber(name) != null) {
    return (key: '$dir|${stripDiscToken(name).toLowerCase()}', switchTitle: false);
  }
  final sw = switchGroupKey(name);
  return sw == null ? null : (key: '$dir|switch:$sw', switchTitle: true);
}

/// Collapses multi-disc sets and Switch titles (base + updates + DLC) in [roms]
/// into single [DiscGroup]s, preserving the input order (a set appears at its
/// first member's position). Files with no disc token and no Switch title id,
/// and lone members with no siblings, stay as singleton groups.
List<DiscGroup> groupDiscs(List<RomResult> roms) {
  final buckets = <String, List<RomResult>>{};
  for (final r in roms) {
    final k = _groupKey(r.filePath);
    if (k != null) buckets.putIfAbsent(k.key, () => []).add(r);
  }
  final multi = {
    for (final e in buckets.entries)
      if (e.value.length > 1) e.key,
  };
  final emitted = <String>{};
  final out = <DiscGroup>[];
  for (final r in roms) {
    final k = _groupKey(r.filePath);
    if (k != null && multi.contains(k.key)) {
      if (emitted.add(k.key)) {
        final members = [...buckets[k.key]!]
          ..sort(k.switchTitle
              ? (a, b) => compareSwitchParts(a.fileName, b.fileName)
              : (a, b) => (discNumber(a.fileName) ?? 0)
                  .compareTo(discNumber(b.fileName) ?? 0));
        out.add(DiscGroup(members, switchTitle: k.switchTitle));
      }
    } else {
      out.add(DiscGroup([r]));
    }
  }
  return out;
}
