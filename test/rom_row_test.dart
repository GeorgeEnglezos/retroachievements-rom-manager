import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/models/rom_row.dart';
import 'package:rarm/services/storage_treemap.dart'
    show TreemapItem;

void main() {
  test('fromRom carries identity, size, progress and the underlying rom', () {
    final rom = RomResult(filePath: r'C:\ROMs\GBA\Game (USA).gba',
        fileName: 'Game (USA).gba');
    rom.fileSize = 4194304;
    rom.gameId = 7;
    rom.earnedAchievements = 3;
    rom.achievementCount = 10; // RomResult.totalAchievements → achievementCount
    final row = RomRow.fromRom(rom);

    expect(row.filePath, rom.filePath);
    expect(row.title, isNotEmpty);
    expect(row.sizeBytes, 4194304);
    expect(row.earnedAchievements, 3);
    expect(row.totalAchievements, 10);
    expect(row.rom, same(rom));
    expect(row.sizeFraction, isNull);
    expect(row.showChevron, isFalse);
  });

  test('fromRom uses a metadataOnly cover url as the row image', () {
    final rom = RomResult(filePath: 'ps3/racer.iso', fileName: 'racer.iso')
      ..status = RomStatus.metadataOnly
      ..imageUrl = 'https://cdn/cover.png';
    expect(RomRow.fromRom(rom).imageIcon, 'https://cdn/cover.png');
  });

  test('fromTreemap is a deletable file row when path is a file', () {
    final item = TreemapItem('Game.gba', 1000, path: r'C:\ROMs\GBA\Game.gba');
    final row = RomRow.fromTreemap(item, fraction: 0.5, isFolder: false);

    expect(row.title, 'Game.gba');
    expect(row.filePath, r'C:\ROMs\GBA\Game.gba');
    expect(row.sizeBytes, 1000);
    expect(row.sizeFraction, 0.5);
    expect(row.showChevron, isFalse);
    expect(row.rom, isNull);
  });

  test('fromTreemap folder row is non-selectable and drillable', () {
    final item = TreemapItem('GBA', 5000, path: r'C:\ROMs\GBA');
    final row = RomRow.fromTreemap(item, fraction: 1.0, isFolder: true);

    expect(row.filePath, isNull);
    expect(row.showChevron, isTrue);
    expect(row.sizeFraction, 1.0);
  });
}
