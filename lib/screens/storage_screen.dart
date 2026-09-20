import 'dart:async' show Timer;
import 'dart:io' show FileSystemEntity;

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/folder_stats.dart' show formatBytes;
import '../models/rom_result.dart';
import '../models/rom_row.dart';
import '../services/console_image.dart';
import '../services/file_actions.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/playlist_store.dart';
import '../services/scan_settings.dart';
import '../services/settings_bus.dart';
import '../services/scraper/scraped_store.dart';
import '../services/storage_scanner.dart';
import '../services/storage_treemap.dart' show TreemapItem;
import '../theme/ui_tokens.dart';
import '../widgets/game_detail_dialog.dart';
import '../widgets/ui/ui_button.dart';
import '../widgets/ui/ui_panel.dart';
import '../widgets/ra_image.dart';
import '../widgets/rom_list_view.dart';
import '../widgets/row_display.dart';

/// One level of the storage drill-down: a title plus the folders/files shown at
/// it, kept sorted by size (largest first).
class _Level {
  final String title;
  final List<TreemapItem> items;

  _Level(this.title, List<TreemapItem> items)
      : items = [...items]..sort((a, b) => b.bytes - a.bytes);

  int get total => items.fold(0, (s, i) => s + i.bytes);
}

/// Storage Analysis: a size-sorted list of per-system folder sizes built from
/// cached [FolderStats]. Tapping a row walks that folder one level down and
/// pushes a new list level.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  final Library _lib = Library.instance;
  final _playlists = PlaylistStore();
  final List<_Level> _stack = [];
  // Console id per root-level system path → its bundled logo (left gutter).
  Map<String, int?> _consoleIds = {};
  // Resolved game per file path → its RA icon in the left gutter. Null value =
  // looked up, no match.
  final Map<String, RomResult?> _fileRoms = {};
  bool _loading = true;
  bool _drilling = false;

  @override
  void initState() {
    super.initState();
    // Re-read after a scan writes new summaries, or a filter changes.
    _lib.addListener(_onIndexChanged);
    settingsChanged.addListener(_onFiltersChanged);
    _load();
  }

  @override
  void dispose() {
    _lib.removeListener(_onIndexChanged);
    settingsChanged.removeListener(_onFiltersChanged);
    _filterDebounce?.cancel();
    super.dispose();
  }

  // A scan wrote new summaries; re-read. Only refresh at the root level so an
  // active drill-down isn't reset.
  void _onIndexChanged() {
    if (!mounted || _stack.length > 1) return;
    _load();
  }

  Timer? _filterDebounce;
  bool _filtersDirty = false;

  // Settings saves on every keystroke and a reload walks every system folder,
  // so filter edits are coalesced into one pass.
  void _onFiltersChanged() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      // Mid-drill-down the reload would reset the level, so hold it until the
      // breadcrumb comes back to the root.
      if (_stack.length > 1) {
        _filtersDirty = true;
        return;
      }
      _load();
    });
  }

  // Applies a filter edit that arrived while the user was drilled down.
  void _reloadIfFiltersChanged() {
    if (_stack.length > 1 || !_filtersDirty) return;
    _filtersDirty = false;
    _load();
  }

  // Current scan filters, so Storage hides exactly what the rest of the app
  // hides (ignored folders, excluded files, non-ROM extensions). Rebuilt each
  // scan so live settings changes take effect.
  Future<StorageFilter> _filter() async => StorageFilter(
        (await ScanSettings.ignoredFolders())
            .map((e) => e.toLowerCase())
            .toSet(),
        (await ScanSettings.excludedFiles())
            .map((e) => e.toLowerCase())
            .toSet(),
        await ScanSettings.enabledExtensions(),
      );

  Future<void> _load() async {
    final summaries = await _lib.summaries();
    final filter = await _filter();
    // Measure filtered on-disk size per system (off the UI isolate) so totals
    // match the drill-down, not just the matched-ROM bytes in each summary.
    final sizes = await compute<(List<String>, StorageFilter), Map<String, int>>(
        systemSizes, ([for (final s in summaries) s.systemPath], filter));
    final items = <TreemapItem>[];
    final consoleIds = <String, int?>{};
    for (final s in summaries) {
      items.add(TreemapItem(
          p.basename(s.systemPath), sizes[s.systemPath] ?? 0,
          path: s.systemPath));
      consoleIds[s.systemPath] =
          await ScanSettings.consoleIdForFolder(s.systemPath);
    }
    if (!mounted) return;
    setState(() {
      _consoleIds = consoleIds;
      _stack
        ..clear()
        ..add(_Level('ALL SYSTEMS', items));
      _loading = false;
    });
  }

  Future<void> _drill(TreemapItem item) async {
    if (item.path == null || _drilling) return;
    setState(() => _drilling = true);
    final kids = await compute<(String, StorageFilter), List<TreemapItem>>(
        childSizes, (item.path!, await _filter()));
    if (!mounted) return;
    if (kids.isNotEmpty) {
      // Resolve each file's game (cheap in-memory lookup) so its icon is ready
      // before the level appears; the drilling overlay covers the wait.
      for (final k in kids) {
        if (k.path != null &&
            _isFile(k.path) &&
            !_fileRoms.containsKey(k.path)) {
          _fileRoms[k.path!] = await resolveRom(k.path!, library: _lib);
        }
      }
      if (!mounted) return;
      setState(() {
        _drilling = false;
        _stack.add(_Level(item.label.toUpperCase(), kids));
      });
    } else {
      setState(() => _drilling = false);
      // A leaf with no children is a file: open the game popup if it maps to a
      // scanned game, otherwise just reveal it in Explorer.
      await _openFile(item.path!);
    }
  }

  Future<void> _openFile(String path) async {
    final rom = await resolveRom(path, library: _lib);
    if (!mounted) return;
    if (rom == null) {
      await FileActions.revealInExplorer(path);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => GameDetailDialog(
        rom: rom,
        store: _playlists,
        onDeleted: _load,
        scraped: ScrapedStore.instance.get(rom.filePath),
      ),
    );
  }

  void _back() {
    if (_stack.length <= 1) return;
    setState(() => _stack.removeLast());
    _reloadIfFiltersChanged();
  }

  // Jumps back to breadcrumb level [i], dropping everything below it.
  void _jumpTo(int i) {
    if (i >= _stack.length - 1) return;
    setState(() => _stack.removeRange(i + 1, _stack.length));
    _reloadIfFiltersChanged();
  }

  // Tappable breadcrumb path + the current level's total size. Every crumb but
  // the last jumps back to that level; the size reflects the live item list, so
  // it drops as rows are deleted.
  Widget _breadcrumb(_Level level) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < _stack.length; i++) ...[
                  if (i > 0) const Text(' / '),
                  _crumb(i),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(formatBytes(level.total)),
      ],
    );
  }

  Widget _crumb(int i) {
    final isLast = i == _stack.length - 1;
    final text = Text(
      _stack[i].title,
      style: TextStyle(
        fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
        decoration: isLast ? null : TextDecoration.underline,
      ),
    );
    if (isLast) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: () => _jumpTo(i), child: text),
    );
  }

  bool _isFile(String? path) =>
      path != null && FileSystemEntity.isFileSync(path);

  // The row's thumbnail: console logo for a root system folder, the matched
  // game's RA icon for a file, and a plain glyph for everything else, so every
  // row keeps the same slot filled and the titles stay on one line.
  Widget _leadingFor(TreemapItem it,
      {required bool isRoot, required bool isFile}) {
    if (isRoot && it.path != null) return _ConsoleLogo(_consoleIds[it.path]);
    if (isFile) {
      final rom = _fileRoms[it.path];
      if (rom != null &&
          rom.status == RomStatus.supported &&
          rom.imageIcon != null) {
        return RaImage(
          url: raImageUrl(rom.imageIcon!),
          fit: BoxFit.cover,
          borderRadius: context.ui.roundMd,
        );
      }
      return _Glyph(Icons.videogame_asset_outlined);
    }
    return _Glyph(Icons.folder_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    if (_loading) return const Center(child: CircularProgressIndicator());

    final level = _stack.last;
    if (level.items.every((i) => i.bytes == 0)) {
      return Center(
        child: Text('NO SCANNED SIZES YET. SCAN A FOLDER FIRST',
            style: ui.labelCaps),
      );
    }

    final isRoot = _stack.length == 1;
    final denom = level.total == 0 ? 1 : level.total;
    final rows = <RomRow>[];
    final leadings = <Widget>[];
    for (final it in level.items) {
      final isFile = _isFile(it.path);
      rows.add(RomRow.fromTreemap(it,
          fraction: it.bytes / denom,
          isFolder: !isFile,
          onTap: it.path == null
              ? null
              : (isFile ? () => _openFile(it.path!) : () => _drill(it))));
      leadings.add(_leadingFor(it, isRoot: isRoot, isFile: isFile));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (_stack.length > 1) ...[
                UiButton(
                  label: 'BACK',
                  icon: Icons.arrow_back,
                  variant: UiButtonVariant.secondary,
                  onPressed: _back,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: UiPanel(child: _breadcrumb(level)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                RomListView(
                  rows: rows,
                  leadings: leadings,
                  display: RowDisplay.storage,
                  store: _playlists,
                  enableSelection: true,
                  onDeleteRow: (r) => _lib.deleteRom(r.filePath!),
                  onRowsRemoved: (removed) => setState(() {
                    final paths = removed.map((r) => r.filePath).toSet();
                    level.items.removeWhere((it) => paths.contains(it.path));
                  }),
                ),
                if (_drilling)
                  Positioned.fill(
                    child: ColoredBox(
                      color: context.ui.background.withValues(alpha: 0.7),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bundled console logo for the storage root's per-system rows, mirroring the
/// folder card's picture (same tint list, folder fallback).
class _ConsoleLogo extends StatelessWidget {
  final int? consoleId;
  const _ConsoleLogo(this.consoleId);

  @override
  Widget build(BuildContext context) {
    final path = ConsoleImage.assetOrGeneric(consoleId);
    final tint = ConsoleImage.tintedLogos.contains(consoleId);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        color: tint ? context.ui.text : null,
        colorBlendMode: tint ? BlendMode.srcIn : null,
        errorBuilder: (_, _, _) => const Icon(Icons.folder, size: 40),
      ),
    );
  }
}

/// Stand-in thumbnail for a row with no picture of its own: a glyph on the
/// raised surface, so the slot reads as filled rather than missing.
class _Glyph extends StatelessWidget {
  final IconData icon;
  const _Glyph(this.icon);

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ui.surfaceAlt,
        borderRadius: ui.roundMd,
        border: Border.all(color: ui.border, width: ui.borderWidth),
      ),
      child: Icon(icon, size: 26, color: ui.muted),
    );
  }
}
