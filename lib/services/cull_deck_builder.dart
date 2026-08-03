import '../models/game_entry.dart';
import '../models/rom_result.dart';
import 'disc_grouping.dart';
import 'game_lookup.dart';
import 'member_key.dart';

/// One deck card: a game (or multi-disc set) plus the member key its verdict
/// is stored under.
class CullCardData {
  /// Representative disc, used for art/metadata (see DiscGroup.representative).
  final RomResult rom;

  /// All discs, length >= 1. Passed to the detail dialog's disc switcher.
  final List<RomResult> discs;

  final String memberKey;

  const CullCardData(
      {required this.rom, required this.discs, required this.memberKey});

  /// Every member key the card covers: one per disc, deduped, [memberKey]
  /// first. A matched set collapses to a single `ra:<id>`, but an unmatched
  /// one keys each disc by its own path, so a trash verdict has to move all of
  /// them or the siblings stay on disk forever after emptying Trash.
  Set<String> get memberKeys => {
        memberKey,
        for (final d in discs)
          memberKeyFor(gameId: d.gameId, filePath: d.filePath),
      };

  /// Display title. An unmatched set falls back to the representative disc's
  /// file name, so the disc token comes off first; same rule as the folder
  /// listing's multi-disc row.
  String get title => gameDisplayName(rom.gameTitle,
      discs.length > 1 ? stripDiscToken(rom.fileName) : rom.fileName);
}

/// Builds every card for one console: rebuilds renderable roms, collapses
/// multi-disc sets, sorts by display title. Decided cards are NOT filtered
/// here; callers subtract CullStore.decided() so the picker can also compute
/// decided/total from this one list.
List<CullCardData> buildCullDeck(List<GameEntry> games,
    {int? consoleId, String? consoleName}) {
  final roms = [
    for (final g in games)
      romFromEntry(g, consoleId: consoleId, consoleName: consoleName)
  ];
  final cards = [
    for (final group in groupDiscs(roms))
      CullCardData(
        rom: group.representative,
        discs: group.discs,
        memberKey: memberKeyFor(
            gameId: group.representative.gameId,
            filePath: group.representative.filePath),
      )
  ];
  cards.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  // Every copy/region of one matched game shares a single member key, so a
  // second card for it would decide the same key twice: one swipe would count
  // as two and one undo would reverse both. Keep the first after sorting.
  final seen = <String>{};
  return [
    for (final c in cards)
      if (seen.add(c.memberKey)) c
  ];
}
