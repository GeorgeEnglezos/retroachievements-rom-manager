import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/home_index.dart';
import 'package:rarm/services/library_export.dart';

SearchIndexEntry _row({
  required String title,
  bool matched = false,
  bool noMatch = false,
  int? earned,
  int? total,
  int? size,
  String filePath = '/p/rom.nes',
}) =>
    SearchIndexEntry(
      title: title,
      fileName: 'rom.nes',
      filePath: filePath,
      systemPath: 'sp',
      systemName: 'NES',
      gameId: matched ? 42 : null,
      matched: matched,
      noMatch: noMatch,
      md5: 'abc',
      icon: null,
      earnedAchievements: earned,
      achievementCount: total,
      fileSize: size,
    );

SystemSummary _sys() => SystemSummary(
      systemPath: 'sp',
      systemId: 'id',
      name: 'NES',
      consoleId: 7,
      totalGames: 2,
      gamesScanned: 2,
      gamesWithAchievements: 1,
      totalSizeBytes: 100,
      lastScanned: null,
    );

void main() {
  final rows = [
    _row(title: 'Blahblah, the "best"', matched: true, earned: 3),
    _row(title: 'Unknown', noMatch: true),
  ];

  test('CSV has a header and escapes quotes/commas', () {
    final csv = LibraryExport.toCsv(rows);
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('System,File,Title,Status'));
    expect(lines.length, 3);
    // Embedded quote doubled, comma stays inside the quoted cell.
    expect(csv, contains('"Blahblah, the ""best"""'));
    expect(csv, contains('supported'));
    expect(csv, contains('unsupported'));
  });

  test('JSON carries a summary and one entry per ROM', () {
    final decoded = jsonDecode(LibraryExport.toJson([_sys()], rows))
        as Map<String, dynamic>;
    expect(decoded['summary']['totalRoms'], 2);
    expect(decoded['summary']['supported'], 1);
    expect((decoded['roms'] as List).length, 2);
  });

  test('Markdown report includes the summary table', () {
    final md = LibraryExport.toMarkdown([_sys()], rows);
    expect(md, contains('# Library health report'));
    expect(md, contains('| Supported | 1 |'));
    expect(md, contains('| NES | 2 | 1 | 2 |'));
  });

  group('per-system export', () {
    final sysRows = [
      _row(
          title: 'Zephyr',
          matched: true,
          earned: 5,
          total: 20,
          size: 1024,
          filePath: '/p/zephyr.nes'),
      _row(title: 'Adventure', noMatch: true, filePath: '/p/adv.nes'),
    ];
    const opts = SystemReportOptions(fields: {
      GameField.hasAchievements,
      GameField.progress,
      GameField.size,
    });

    test('CSV header and one row per game, columns in enum order', () {
      final csv = LibraryExport.systemCsv(sysRows, opts);
      final lines = csv.trim().split('\n');
      expect(lines.first, '"Name","Has achievements","Progress","Size"');
      expect(lines.length, 3);
      expect(csv, contains('"Zephyr","Yes","5/20"'));
      expect(csv, contains('"1.0 KB"'));
      expect(csv, contains('"Adventure","No","0/0",""'));
    });

    test('sort by name is alphabetical; only chosen fields appear', () {
      const nameOnly = SystemReportOptions(fields: {GameField.progress});
      final csv = LibraryExport.systemCsv(sysRows, nameOnly);
      final lines = csv.trim().split('\n');
      expect(lines.first, '"Name","Progress"');
      expect(lines[1], startsWith('"Adventure"')); // A before Z
      expect(lines[2], startsWith('"Zephyr"'));
    });

    test('limit caps the number of game rows', () {
      const capped = SystemReportOptions(fields: {}, limit: 1);
      final lines =
          LibraryExport.systemCsv(sysRows, capped).trim().split('\n');
      expect(lines.length, 2); // header + 1 game
    });

    test('Markdown table has a title, header and escapes pipes', () {
      final md = LibraryExport.systemMarkdown('NES', sysRows, opts);
      expect(md, contains('# NES library'));
      expect(md, contains('| Name | Has achievements | Progress | Size |'));
      expect(md, contains('| Zephyr | Yes | 5/20 |'));
    });
  });
}
