import 'dart:convert';

import '../models/folder_stats.dart' show formatBytes;
import '../models/home_index.dart';
import '../models/rom_result.dart';
import 'scan_health.dart';

/// Optional columns for a per-system game-list export. Iteration/enum order is
/// also the column order in the output.
enum GameField { hasAchievements, progress, size }

/// User choices for a per-system game-list export.
class SystemReportOptions {
  final Set<GameField> fields;
  final int? limit; // null = all games

  const SystemReportOptions({
    this.fields = const {},
    this.limit,
  });
}

/// Pure builders that turn the scanned library into exportable report text.
/// No file I/O here; the caller writes the returned string to disk.
class LibraryExport {
  LibraryExport._();

  static String _status(SearchIndexEntry e) => e.matched
      ? 'supported'
      : e.noMatch
          ? 'unsupported'
          : 'not fetched';

  // RFC 4180-ish: quote always, double embedded quotes. Keeps commas/newlines
  // in titles safe. A leading =, +, -, or @ is prefixed with ' so a title/filename
  // isn't run as a formula when the CSV is opened in Excel/Sheets (CSV injection).
  static String _csvCell(Object? v) {
    var s = (v ?? '').toString();
    // A one-char cell can't be a formula, so leave lone placeholders like "-".
    if (s.length > 1 && '=+-@'.contains(s[0])) s = "'$s";
    return '"${s.replaceAll('"', '""')}"';
  }

  /// One row per ROM. Columns: System, File, Title, Status, GameID, Earned, MD5.
  static String toCsv(List<SearchIndexEntry> rows) {
    final buf = StringBuffer(
        'System,File,Title,Status,GameID,EarnedAchievements,MD5\n');
    for (final e in rows) {
      buf.writeln([
        _csvCell(e.systemName),
        _csvCell(e.fileName),
        _csvCell(e.title),
        _csvCell(_status(e)),
        _csvCell(e.gameId),
        _csvCell(e.earnedAchievements),
        _csvCell(e.md5),
      ].join(','));
    }
    return buf.toString();
  }

  /// Structured export: a health summary plus the full per-ROM list.
  static String toJson(
      List<SystemSummary> systems, List<SearchIndexEntry> rows) {
    final health = ScanHealth.fromIndex(systems, rows);
    return const JsonEncoder.withIndent('  ').convert({
      'summary': {
        'totalRoms': health.totalRoms,
        'supported': health.supported,
        'unsupported': health.unsupported,
        'notFetched': health.notFetched,
        'withProgress': health.withProgress,
        'systems': health.systems,
        'totalSizeBytes': health.totalSizeBytes,
      },
      'systems': [
        for (final s in systems)
          {
            'systemPath': s.systemPath,
            'systemId': s.systemId,
            'name': s.name,
            'consoleId': s.consoleId,
            'totalGames': s.totalGames,
            'gamesScanned': s.gamesScanned,
            'gamesWithAchievements': s.gamesWithAchievements,
            'totalSizeBytes': s.totalSizeBytes,
            'lastScanned': s.lastScanned?.toIso8601String(),
          },
      ],
      'roms': [
        for (final e in rows)
          {
            'system': e.systemName,
            'file': e.fileName,
            'title': e.title,
            'status': _status(e),
            'gameId': e.gameId,
            'earnedAchievements': e.earnedAchievements,
            'md5': e.md5,
          },
      ],
    });
  }

  // --- Per-system game-list export (name + chosen fields) -------------------

  static const _fieldHeaders = {
    GameField.hasAchievements: 'Has achievements',
    GameField.progress: 'Progress',
    GameField.size: 'Size',
  };

  /// Ordered subset of [fields], in enum/column order. For the PDF builder.
  static List<GameField> orderedFields(Set<GameField> fields) =>
      _orderedFields(fields);

  /// Header labels for [fields], in column order. For the PDF builder.
  static List<String> fieldHeaders(Set<GameField> fields) =>
      [for (final f in _orderedFields(fields)) _fieldHeaders[f]!];

  /// One field's displayed value for [e]. For the PDF builder.
  static String fieldValue(GameField f, SearchIndexEntry e) =>
      _fieldValue(f, e);

  static String _fieldValue(GameField f, SearchIndexEntry e) {
    switch (f) {
      case GameField.hasAchievements:
        return (e.achievementCount ?? 0) > 0 ? 'Yes' : 'No';
      case GameField.progress:
        return '${e.earnedAchievements ?? 0}/${e.achievementCount ?? 0}';
      case GameField.size:
        return e.fileSize == null ? '' : formatBytes(e.fileSize!);
    }
  }

  /// Sorts by name, then applies the row limit. Exposed so the PDF builder
  /// shares the exact same ordering/limit.
  static List<SearchIndexEntry> prepareRows(
      List<SearchIndexEntry> rows, SystemReportOptions options) {
    String name(SearchIndexEntry e) =>
        gameDisplayName(e.title, e.fileName).toLowerCase();
    final list = [...rows]..sort((a, b) => name(a).compareTo(name(b)));
    final limit = options.limit;
    return limit == null ? list : list.take(limit).toList();
  }

  static List<GameField> _orderedFields(Set<GameField> fields) =>
      GameField.values.where(fields.contains).toList();

  /// Per-system CSV: a Name column plus one column per chosen field.
  static String systemCsv(
      List<SearchIndexEntry> rows, SystemReportOptions options) {
    final fields = _orderedFields(options.fields);
    final buf = StringBuffer(
        ['Name', ...fields.map((f) => _fieldHeaders[f])].map(_csvCell).join(','))
      ..write('\n');
    for (final e in prepareRows(rows, options)) {
      buf.writeln([
        _csvCell(gameDisplayName(e.title, e.fileName)),
        for (final f in fields) _csvCell(_fieldValue(f, e)),
      ].join(','));
    }
    return buf.toString();
  }

  /// Per-system Markdown table: a Name column plus one column per chosen field.
  static String systemMarkdown(String systemName, List<SearchIndexEntry> rows,
      SystemReportOptions options) {
    final fields = _orderedFields(options.fields);
    final headers = ['Name', ...fields.map((f) => _fieldHeaders[f]!)];
    final buf = StringBuffer('# $systemName library\n\n');
    buf.writeln('| ${headers.join(' | ')} |');
    buf.writeln('| ${headers.map((_) => '---').join(' | ')} |');
    for (final e in prepareRows(rows, options)) {
      final cells = [
        gameDisplayName(e.title, e.fileName),
        for (final f in fields) _fieldValue(f, e),
      ].map((c) => c.replaceAll('|', r'\|'));
      buf.writeln('| ${cells.join(' | ')} |');
    }
    return buf.toString();
  }

  /// Human-readable Markdown report: summary table + per-system counts.
  static String toMarkdown(
      List<SystemSummary> systems, List<SearchIndexEntry> rows) {
    final h = ScanHealth.fromIndex(systems, rows);
    final buf = StringBuffer('# Library health report\n\n');
    buf.writeln('| Metric | Count |');
    buf.writeln('| --- | --- |');
    buf.writeln('| Total ROMs | ${h.totalRoms} |');
    buf.writeln('| Supported | ${h.supported} |');
    buf.writeln('| Unsupported | ${h.unsupported} |');
    buf.writeln('| Not fetched | ${h.notFetched} |');
    buf.writeln('| With progress | ${h.withProgress} |');
    buf.writeln('| Systems | ${h.systems} |');
    buf.writeln('\n## Per system\n');
    buf.writeln('| System | Games | Supported | Scanned |');
    buf.writeln('| --- | --- | --- | --- |');
    final sorted = [...systems]..sort((a, b) => a.name.compareTo(b.name));
    for (final s in sorted) {
      buf.writeln('| ${s.name} | ${s.totalGames} | '
          '${s.gamesWithAchievements} | ${s.gamesScanned} |');
    }
    return buf.toString();
  }
}
