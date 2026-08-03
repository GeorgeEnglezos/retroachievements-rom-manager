import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_entry.dart';
import 'package:rarm/services/cull_deck_builder.dart';
import 'package:rarm/services/ra_service.dart';

GameEntry entry(String fileName, {int? gameId, String? title}) => GameEntry(
      filePath: 'C:/roms/psx/$fileName',
      fileName: fileName,
      fileSize: 100,
      md5: null,
      gameId: gameId,
      matched: gameId != null,
      noMatch: false,
      lastScanned: DateTime(2026),
      gameInfo: gameId == null
          ? null
          : GameInfo(
              gameId: gameId,
              title: title ?? fileName,
              consoleName: 'PlayStation',
              consoleId: 12,
              achievementCount: 10,
              imageIcon: '/Images/icon.png',
              imageBoxArt: '/Images/box.png',
              imageTitle: '/Images/title.png',
              imageIngame: '/Images/ingame.png',
            ),
      progress: null,
    );

void main() {
  test('collapses a multi-disc set into one card keyed once', () {
    final cards = buildCullDeck([
      entry('Zeta Quest (Disc 1).chd'),
      entry('Zeta Quest (Disc 2).chd'),
      entry('Mono Run.chd'),
    ]);
    expect(cards.length, 2);
    final zeta = cards.firstWhere((c) => c.discs.length == 2);
    expect(zeta.memberKey, startsWith('path:'));
  });

  test('sorts cards alphabetically by display title', () {
    final cards = buildCullDeck([
      entry('bravo.gb'),
      entry('alpha.gb'),
    ]);
    expect(cards.map((c) => c.rom.fileName).toList(),
        ['alpha.gb', 'bravo.gb']);
  });

  test('a matched game is keyed by RA game id', () {
    final cards = buildCullDeck([entry('zeta.chd', gameId: 77)]);
    expect(cards.single.memberKey, 'ra:77');
  });

  test('two copies of one matched game collapse to a single card', () {
    // Both copies key to ra:77, and a duplicate card would make one swipe
    // decide two cards (and one undo reverse both).
    final cards = buildCullDeck([
      entry('zeta (USA).chd', gameId: 77, title: 'Zeta Quest'),
      entry('zeta (Europe).chd', gameId: 77, title: 'Zeta Quest'),
      entry('mono.chd', gameId: 78, title: 'Mono Run'),
    ]);
    expect(cards.map((c) => c.memberKey).toList(), ['ra:78', 'ra:77']);
  });

  test('memberKeys covers every disc of an unmatched multi-disc set', () {
    final cards = buildCullDeck([
      entry('Zeta Quest (Disc 1).chd'),
      entry('Zeta Quest (Disc 2).chd'),
    ]);
    final zeta = cards.single;
    expect(zeta.memberKeys, {
      'path:C:/roms/psx/Zeta Quest (Disc 1).chd',
      'path:C:/roms/psx/Zeta Quest (Disc 2).chd',
    });
    // The primary stays first, and it is what the decided set uses.
    expect(zeta.memberKeys.first, zeta.memberKey);
  });

  test('an unmatched multi-disc set drops the disc token from its title', () {
    final cards = buildCullDeck([
      entry('Zeta Quest (Disc 1).chd'),
      entry('Zeta Quest (Disc 2).chd'),
    ]);
    expect(cards.single.title, 'Zeta Quest.chd');
  });

  test('a lone file keeps its name verbatim', () {
    final cards = buildCullDeck([entry('Zeta Quest (Disc 1).chd')]);
    expect(cards.single.title, 'Zeta Quest (Disc 1).chd');
  });

  test('memberKeys of a matched set collapses to the one RA key', () {
    final cards = buildCullDeck([
      entry('Zeta Quest (Disc 1).chd', gameId: 77, title: 'Zeta Quest'),
      entry('Zeta Quest (Disc 2).chd', gameId: 77, title: 'Zeta Quest'),
    ]);
    expect(cards.single.memberKeys, {'ra:77'});
  });
}
