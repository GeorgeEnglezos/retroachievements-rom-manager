import 'dart:typed_data';

import 'ra_image_cache.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/home_index.dart';
import '../models/rom_result.dart' show gameDisplayName;
import '../widgets/ra_image.dart' show raImageUrl;
import 'library_export.dart';
import 'log_service.dart';

/// Per-system game-list PDF (icon + name + chosen fields). A bad icon is
/// skipped, never failing the document.
Future<Uint8List> buildSystemPdf(
  String systemName,
  List<SearchIndexEntry> rows,
  SystemReportOptions options,
) async {
  final games = LibraryExport.prepareRows(rows, options);
  final icons = await _fetchIcons(games);

  final doc = pw.Document();
  final headers = ['', 'Name', ...LibraryExport.fieldHeaders(options.fields)];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(level: 0, text: '$systemName library'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {0: const pw.FixedColumnWidth(28)},
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                for (final h in headers) _cell(pw.Text(h, style: _bold)),
              ],
            ),
            for (final e in games)
              pw.TableRow(children: [
                _cell(icons[e.filePath] == null
                    ? pw.SizedBox(width: 20, height: 20)
                    : pw.Image(icons[e.filePath]!, width: 20, height: 20)),
                _cell(pw.Text(gameDisplayName(e.title, e.fileName))),
                for (final f in LibraryExport.orderedFields(options.fields))
                  _cell(pw.Text(LibraryExport.fieldValue(f, e))),
              ]),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

final _bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

pw.Widget _cell(pw.Widget child) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: child,
    );

Future<Map<String, pw.MemoryImage>> _fetchIcons(
    List<SearchIndexEntry> games) async {
  final out = <String, pw.MemoryImage>{};
  for (final e in games) {
    final icon = e.icon;
    if (icon == null || icon.isEmpty) continue;
    try {
      final file = await raCacheManager.getSingleFile(raImageUrl(icon));
      out[e.filePath] = pw.MemoryImage(await file.readAsBytes());
    } catch (err) {
      LogService.error('LibraryPdfExport', 'icon fetch failed', err: err);
    }
  }
  return out;
}
