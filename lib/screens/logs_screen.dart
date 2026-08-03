import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../services/log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  // null = live session view
  String? _selectedLogFile;
  String? _selectedLogContent;
  List<File> _logFiles = [];
  bool _loadingFile = false;

  @override
  void initState() {
    super.initState();
    _refreshFileList();
  }

  Future<void> _refreshFileList() async {
    final dir = LogService.logFolderPath;
    if (dir == null) return;
    final d = Directory(dir);
    if (!await d.exists()) return;

    final files = await d
        .list()
        .where((e) => e is File && p.basename(e.path).startsWith('session_'))
        .cast<File>()
        .toList();

    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));

    if (mounted) setState(() => _logFiles = files);
  }

  Future<void> _selectFile(File file) async {
    setState(() {
      _selectedLogFile = file.path;
      _loadingFile = true;
      _selectedLogContent = null;
    });
    final content = await file.readAsString();
    if (mounted) {
      setState(() {
        _selectedLogContent = content;
        _loadingFile = false;
      });
    }
  }

  void _selectLive() {
    setState(() {
      _selectedLogFile = null;
      _selectedLogContent = null;
    });
  }

  String _friendlyName(String path) {
    final base = p.basenameWithoutExtension(path);
    // session_2026-03-22_14-05-30 → 2026-03-22 14:05:30
    return base
        .replaceFirst('session_', '')
        .replaceFirst('_', ' ')
        .replaceAllMapped(
          RegExp(r'(\d{2})-(\d{2})-(\d{2})$'),
          (m) => '${m[1]}:${m[2]}:${m[3]}',
        );
  }

  Color _levelColor(LogLevel level, BuildContext context) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // The shell already shows the tab title on mobile; avoid a doubled header.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: wide ? const Text('Logs') : null,
        actions: [
          if (_selectedLogFile == null)
            IconButton(
              onPressed: LogService.clear,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear current session logs',
            ),
          if (_selectedLogContent != null)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _selectedLogContent!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy),
              tooltip: 'Copy log to clipboard',
            ),
          IconButton(
            onPressed: _refreshFileList,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh file list',
          ),
        ],
      ),
      // Rebuild whenever LogService notifies (new entries / cleared).
      body: ListenableBuilder(
        listenable: LogService.instance,
        builder: (context, _) {
          final liveEntries = LogService.entries;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: file list
                SizedBox(
                  // Narrower sidebar on phones so the detail pane isn't squeezed.
                  width: MediaQuery.sizeOf(context).width < 600 ? 120 : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live session entry
                      _FileListTile(
                        label: 'Current session',
                        icon: Icons.circle,
                        iconColor: Colors.greenAccent,
                        selected: _selectedLogFile == null,
                        onTap: _selectLive,
                      ),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 4),
                      if (_logFiles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No saved logs',
                            style: TextStyle(color: secondary, fontSize: 12),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _logFiles.length,
                            itemBuilder: (context, i) {
                              final file = _logFiles[i];
                              return _FileListTile(
                                label: _friendlyName(file.path),
                                icon: Icons.description_outlined,
                                selected: _selectedLogFile == file.path,
                                onTap: () => _selectFile(file),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),
                const VerticalDivider(),
                const SizedBox(width: 16),

                // Right: content
                Expanded(
                  child: _selectedLogFile == null
                      ? _LiveView(
                          entries: liveEntries,
                          levelColor: (level) => _levelColor(level, context),
                          secondary: secondary,
                        )
                      : _loadingFile
                          ? const Center(child: CircularProgressIndicator())
                          : _FileView(
                              content: _selectedLogContent ?? '',
                              secondary: secondary,
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Sub-widgets

class _FileListTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _FileListTile({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = scheme.onSurfaceVariant;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor ?? textColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? scheme.primary : textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveView extends StatefulWidget {
  final List<LogEntry> entries;
  final Color Function(LogLevel) levelColor;
  final Color secondary;

  const _LiveView({
    required this.entries,
    required this.levelColor,
    required this.secondary,
  });

  @override
  State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LiveView old) {
    super.didUpdateWidget(old);
    if (widget.entries.length != old.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(
          'No logs yet.',
          style: TextStyle(color: widget.secondary),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      itemCount: widget.entries.length,
      itemBuilder: (context, index) {
        final e = widget.entries[index];
        final ts = e.timestamp
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 23);
        final color = widget.levelColor(e.level);

        // One rich line that wraps instead of a horizontal Row of fixed-width
        // monospace fields, which overflowed on narrow/phone widths.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              children: [
                TextSpan(text: '$ts ', style: TextStyle(color: widget.secondary)),
                TextSpan(
                  text: '[${e.level.name.toUpperCase().padRight(5)}] ',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: '${e.source}: ',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: e.message, style: TextStyle(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FileView extends StatelessWidget {
  final String content;
  final Color secondary;

  const _FileView({required this.content, required this.secondary});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Center(
        child: Text(
          'Empty log file.',
          style: TextStyle(color: secondary),
        ),
      );
    }

    return SingleChildScrollView(
      child: SelectableText(
        content,
        style: TextStyle(
          fontSize: 11,
          fontFamily: 'monospace',
          color: secondary,
        ),
      ),
    );
  }
}
