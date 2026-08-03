import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/home_index.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/search_service.dart';

SearchIndexEntry _row({
  String? title,
  required String fileName,
  String systemName = 'SNES',
  String systemPath = 'C:/roms/snes',
  bool matched = true,
}) =>
    SearchIndexEntry(
      title: title,
      fileName: fileName,
      filePath: '$systemPath/$fileName',
      systemPath: systemPath,
      systemName: systemName,
      gameId: matched ? 1 : null,
      matched: matched,
      noMatch: false,
      md5: null,
      icon: null,
      earnedAchievements: null,
      achievementCount: matched ? 10 : null,
      fileSize: null,
    );

void main() {
  test('matches on title or file name, case-insensitive', () {
    final hits = buildSearchHits([
      _row(title: 'Super Blahblah World', fileName: 'smw.sfc'),
      _row(title: 'Gizmo', fileName: 'blahblah kart.sfc'),
      _row(title: 'Gadget', fileName: 'gadget.sfc'),
    ], 'BLAHBLAH');
    expect(hits.length, 2);
  });

  test('exclude terms drop rows matching file name or title', () {
    final hits = buildSearchHits(
      [
        _row(title: 'Blahblah (USA)', fileName: 'blahblah-usa.sfc'),
        _row(title: 'Blahblah (Japan)', fileName: 'blahblah-jp.sfc'),
      ],
      'blahblah',
      excludeTerms: ['japan'],
    );
    expect(hits.length, 1);
    expect(hits.single.rom.fileName, 'blahblah-usa.sfc');
  });

  test('results sort by system name', () {
    final hits = buildSearchHits(
      [
        _row(title: 'Blahblah Golf', fileName: 'wg.z64',
            systemName: 'N64', systemPath: 'C:/roms/n64'),
        _row(title: 'Blahblah World', fileName: 'smw.sfc'),
      ],
      'blahblah',
    );
    expect(hits.map((h) => h.systemName), ['N64', 'SNES']);
  });

  test('unmatched rows come through as notFetched', () {
    final hits =
        buildSearchHits([_row(fileName: 'mystery blahblah.bin', matched: false)],
            'blahblah');
    expect(hits.single.rom.status, RomStatus.notFetched);
  });
}
