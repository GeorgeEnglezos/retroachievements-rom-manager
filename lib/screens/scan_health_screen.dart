import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/folder_stats.dart' show formatBytes;
import '../models/home_index.dart';
import '../services/library.dart';
import '../services/library_export.dart';
import '../services/library_pdf_export.dart';
import '../services/log_service.dart';
import '../services/scan_health.dart';
import '../widgets/ui/ui_focusable.dart';
import '../strings.dart';

/// Read-only summary of the scanned library, plus report export. Turns the raw
/// scan results ([Library]) into decision-oriented counts, and lets the user
/// export them as CSV / JSON / Markdown.
class ScanHealthScreen extends StatefulWidget {
  const ScanHealthScreen({super.key});

  @override
  State<ScanHealthScreen> createState() => _ScanHealthScreenState();
}

class _ScanHealthScreenState extends State<ScanHealthScreen> {
  final _store = Library.instance;
  ScanHealth? _health;
  List<SystemSummary> _systems = const [];
  List<SearchIndexEntry> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final systems = await _store.summaries();
    final rows = await _store.searchIndex();
    if (!mounted) return;
    setState(() {
      _systems = systems;
      _rows = rows;
      _health = ScanHealth.fromIndex(systems, rows);
    });
  }

  Future<void> _export(String ext, String Function() build) =>
      _saveTo(ScanHealthStrings.reportFileName(ext), (f) => f.writeAsString(build()));

  /// Prompts for a path then runs [write] against the chosen file, with the
  /// shared success/failure snackbars.
  Future<void> _saveTo(
      String fileName, Future<void> Function(File) write) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: ScanHealthStrings.exportDialogTitle,
        fileName: fileName,
      );
      if (path == null) return; // cancelled
      await write(File(path));
      messenger.showSnackBar(SnackBar(content: Text(ScanHealthStrings.savedTo(path))));
    } catch (e) {
      LogService.error('ScanHealthScreen/export', 'Failed', err: e);
      messenger
          .showSnackBar(const SnackBar(content: Text(ScanHealthStrings.exportFailed)));
    }
  }

  Future<void> _exportSystem() async {
    final cfg = await showDialog<_SystemExportConfig>(
      context: context,
      builder: (_) => _SystemExportDialog(systems: _systems),
    );
    if (cfg == null || !mounted) return;

    final rows =
        _rows.where((r) => r.systemPath == cfg.systemPath).toList();
    final opts = SystemReportOptions(fields: cfg.fields, limit: cfg.limit);
    final base = ScanHealthStrings.systemReportBase(cfg.systemName);
    switch (cfg.format) {
      case 'csv':
        await _saveTo('$base.csv',
            (f) => f.writeAsString(LibraryExport.systemCsv(rows, opts)));
      case 'md':
        await _saveTo(
            '$base.md',
            (f) => f.writeAsString(LibraryExport.systemMarkdown(
                cfg.systemName, rows, opts)));
      case 'pdf':
        await _saveTo(
            '$base.pdf',
            (f) async => f.writeAsBytes(
                await buildSystemPdf(cfg.systemName, rows, opts)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _health;
    return Scaffold(
      appBar: AppBar(title: const Text(ScanHealthStrings.title)),
      body: h == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statCard(ScanHealthStrings.totalRoms, h.totalRoms, Icons.videogame_asset),
                _statCard(ScanHealthStrings.supported, h.supported, Icons.check_circle,
                    color: Colors.green),
                _statCard(ScanHealthStrings.unsupported, h.unsupported, Icons.cancel,
                    color: Colors.red),
                _statCard(ScanHealthStrings.notFetched, h.notFetched,
                    Icons.cloud_download_outlined),
                _statCard(ScanHealthStrings.withProgress, h.withProgress, Icons.emoji_events,
                    color: Colors.amber),
                _statCard(LibraryStrings.systems, h.systems, Icons.dns),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    ScanHealthStrings.summary(formatBytes(h.totalSizeBytes),
                        (h.supportedRatio * 100).round()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Divider(height: 32),
                Text(ScanHealthStrings.exportReport,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    UiFocusZoom(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text(ScanHealthStrings.csv),
                        onPressed: () =>
                            _export('csv', () => LibraryExport.toCsv(_rows)),
                      ),
                    ),
                    UiFocusZoom(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.data_object),
                        label: const Text(ScanHealthStrings.json),
                        onPressed: () => _export(
                            'json', () => LibraryExport.toJson(_systems, _rows)),
                      ),
                    ),
                    UiFocusZoom(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.description_outlined),
                        label: const Text(ScanHealthStrings.markdown),
                        onPressed: () => _export('md',
                            () => LibraryExport.toMarkdown(_systems, _rows)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Text(ScanHealthStrings.exportOneSystem,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  ScanHealthStrings.exportOneSystemHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: UiFocusZoom(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text(ScanHealthStrings.exportSystemButton),
                      onPressed: _systems.isEmpty ? null : _exportSystem,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String label, int value, IconData icon, {Color? color}) {
    return Card(
      child: UiFocusZoom(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          trailing: Text('$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

/// The user's choices from [_SystemExportDialog].
class _SystemExportConfig {
  final String systemPath;
  final String systemName;
  final Set<GameField> fields;
  final int? limit;
  final String format; // 'csv' | 'md' | 'pdf'

  _SystemExportConfig({
    required this.systemPath,
    required this.systemName,
    required this.fields,
    required this.limit,
    required this.format,
  });
}

/// Picks a system, the columns/order/limit, then a format. Pops a
/// [_SystemExportConfig] (the format is chosen by which format button is
/// tapped) or null on cancel.
class _SystemExportDialog extends StatefulWidget {
  const _SystemExportDialog({required this.systems});

  final List<SystemSummary> systems;

  @override
  State<_SystemExportDialog> createState() => _SystemExportDialogState();
}

class _SystemExportDialogState extends State<_SystemExportDialog> {
  late SystemSummary _system = widget.systems.first;
  final _fields = <GameField>{
    GameField.hasAchievements,
    GameField.progress,
    GameField.size,
  };
  int? _limit; // null = All

  static const _fieldLabels = {
    GameField.hasAchievements: ScanHealthStrings.hasAchievements,
    GameField.progress: ScanHealthStrings.progress,
    GameField.size: ScanHealthStrings.size,
  };

  _SystemExportConfig _config(String format) => _SystemExportConfig(
        systemPath: _system.systemPath,
        systemName: _system.name,
        fields: _fields,
        limit: _limit,
        format: format,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(ScanHealthStrings.exportSystemTitle),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiFocusZoom(
                child: DropdownButtonFormField<SystemSummary>(
                  initialValue: _system,
                  decoration: const InputDecoration(labelText: ScanHealthStrings.systemLabel),
                  items: [
                    for (final s in widget.systems)
                      DropdownMenuItem(
                        value: s,
                        child: UiFocusZoom(child: Text(s.name)),
                      ),
                  ],
                  onChanged: (s) => setState(() => _system = s!),
                ),
              ),
              const SizedBox(height: 16),
              const Text(ScanHealthStrings.fieldsLabel),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in GameField.values)
                    UiFocusZoom(
                      child: FilterChip(
                        label: Text(_fieldLabels[f]!),
                        selected: _fields.contains(f),
                        onSelected: (on) => setState(
                            () => on ? _fields.add(f) : _fields.remove(f)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(ScanHealthStrings.howMany),
              UiFocusZoom(
                child: SegmentedButton<int?>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 50, label: Text('50')),
                    ButtonSegment(value: null, label: Text(ScanHealthStrings.all)),
                  ],
                  selected: {_limit},
                  onSelectionChanged: (s) => setState(() => _limit = s.first),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(LibraryStrings.cancelButton),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context, _config('csv')),
            child: const Text(ScanHealthStrings.csv),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context, _config('md')),
            child: const Text(ScanHealthStrings.markdown),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context, _config('pdf')),
            child: const Text(ScanHealthStrings.pdf),
          ),
        ),
      ],
    );
  }
}
