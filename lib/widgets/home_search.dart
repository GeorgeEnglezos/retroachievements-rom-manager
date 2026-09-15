import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_index.dart';
import '../models/rom_group.dart';
import '../models/rom_row.dart';
import '../services/console_map.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/log_service.dart';
import '../services/playlist_store.dart';
import '../services/ra_service.dart';
import '../services/scan_settings.dart';
import '../services/scraper/scraped_store.dart';
import '../services/search_service.dart';
import '../theme/ui_tokens.dart';
import 'game_detail_dialog.dart';
import 'require_credentials.dart';
import 'rom_list_view.dart';
import 'row_display.dart';

/// Global search over the home index. With no query it renders [child] and
/// shows [idleActions] beside the bar.
class HomeSearch extends StatefulWidget {
  final PlaylistStore store;
  final Future<void> Function() onPlaylistChanged;
  final List<Widget> idleActions;

  /// Idle actions pinned to the right edge, past the scrolling [idleActions].
  final List<Widget> idleTrailing;
  final Widget child;

  /// Injectable for tests; the app always searches the shared library.
  final Library? library;

  /// Opens the system folder at the given path. When null, folder results are
  /// not shown (nothing could open them).
  final void Function(String systemPath)? onOpenFolder;

  const HomeSearch({
    super.key,
    required this.store,
    required this.onPlaylistChanged,
    required this.idleActions,
    this.idleTrailing = const [],
    required this.child,
    this.library,
    this.onOpenFolder,
  });

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  late final Library _lib = widget.library ?? Library.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();
  String _searchQuery = '';
  final List<String> _excludeTerms = [];
  bool _searchSectioned = true;
  List<SearchHit> _searchHits = [];
  List<SystemSummary> _folderHits = [];
  bool _searchPending = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {
      _searchQuery = value;
      if (value.isEmpty) {
        _excludeTerms.clear();
        _excludeController.clear();
        _searchHits = [];
        _folderHits = [];
        _searchPending = false;
      } else {
        _searchPending = true;
      }
    });
    if (value.isEmpty) return;
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(value),
    );
  }

  void _addExcludeTerm(String value) {
    final term = value.trim();
    _excludeController.clear();
    if (term.isEmpty || _excludeTerms.contains(term.toLowerCase())) return;
    setState(() => _excludeTerms.add(term.toLowerCase()));
    if (_searchQuery.isNotEmpty) _runSearch(_searchQuery);
  }

  void _removeExcludeTerm(String term) {
    setState(() => _excludeTerms.remove(term));
    if (_searchQuery.isNotEmpty) _runSearch(_searchQuery);
  }

  Future<void> _runSearch(String query) async {
    final rows = await _lib.searchIndex();
    // Only bother resolving folder matches when a tap can actually open them.
    final systems =
        widget.onOpenFolder == null ? const <SystemSummary>[] : await _lib.summaries();
    if (query != _searchQuery || !mounted) return;
    final hits = buildSearchHits(
      rows,
      query,
      excludeTerms: List<String>.from(_excludeTerms),
    );
    final folders = matchFolders(systems, query);
    if (mounted && query == _searchQuery) {
      setState(() {
        _searchHits = hits;
        _folderHits = folders;
        _searchPending = false;
      });
    }
  }

  Widget _buildSearchBar() {
    final searchField = TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search games…',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
      ),
      onChanged: _onSearchChanged,
    );
    final excludeField = TextField(
      controller: _excludeController,
      decoration: const InputDecoration(
        hintText: 'Exclude results containing… (Enter to add)',
        prefixIcon: Icon(Icons.search_off),
        isDense: true,
      ),
      onSubmitted: _addExcludeTerm,
    );
    final excludeChips = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final term in _excludeTerms)
          Chip(
            label: Text(term),
            visualDensity: VisualDensity.compact,
            onDeleted: () => _removeExcludeTerm(term),
          ),
      ],
    );
    final searchColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        searchField,
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 4),
          excludeField,
          if (_excludeTerms.isNotEmpty) ...[
            const SizedBox(height: 4),
            excludeChips,
          ],
        ],
      ],
    );
    // 40px square so icon buttons don't balloon the row.
    final compactIconButton = IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    // During a search only options that change the result list stay visible.
    final actions = _searchQuery.isNotEmpty
        ? <Widget>[
            IconButton(
              style: compactIconButton,
              icon: Icon(_searchSectioned
                  ? Icons.format_list_bulleted
                  : Icons.view_agenda_outlined),
              tooltip: _searchSectioned ? 'Flat list' : 'Grouped list',
              onPressed: () =>
                  setState(() => _searchSectioned = !_searchSectioned),
            ),
            IconButton(
              style: compactIconButton,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh results',
              onPressed:
                  _searchPending ? null : () => _runSearch(_searchQuery),
            ),
          ]
        : widget.idleActions;
    final trailing =
        _searchQuery.isNotEmpty ? const <Widget>[] : widget.idleTrailing;
    // Narrow: full-width field, actions below. Wide: centered 60% row.
    final wide = MediaQuery.sizeOf(context).width >= kBreakCompact;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: wide
          ? Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: searchColumn),
                    const SizedBox(width: 8),
                    ...actions,
                    ...trailing,
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchColumn,
                const SizedBox(height: 4),
                // Actions scroll if they outgrow the width; trailing stays
                // pinned to the right edge.
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions,
                        ),
                      ),
                    ),
                    ...trailing,
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _searchQuery.isEmpty ? widget.child : _buildSearchResults(),
        ),
      ],
    );
  }

  // RomListView owns selection/bulk-bar/delete. The ValueKey on the query
  // resets selection on new searches.
  Widget _buildSearchResults() {
    if (_searchPending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchHits.isEmpty && _folderHits.isEmpty) {
      return Center(child: Text('Nothing found for "$_searchQuery"'));
    }
    if (_searchHits.isEmpty) {
      // Folder matches only (e.g. an empty or unscanned system).
      return ListView(children: _folderResultTiles());
    }

    List<RomGroup>? groups;
    List<RomRow> rows = const [];

    if (_searchSectioned) {
      final groupMap = <String, List<RomRow>>{};
      for (final h in _searchHits) {
        groupMap.putIfAbsent(h.systemName, () => []).add(
          RomRow.fromRom(h.rom, onTap: () => _openHit(h)),
        );
      }
      final names = groupMap.keys.toList()..sort();
      groups = [
        for (final n in names)
          RomGroup(
            label: '$n · ${groupMap[n]!.length} ${groupMap[n]!.length == 1 ? "result" : "results"}',
            rows: groupMap[n]!,
          ),
      ];
    } else {
      rows = _searchHits
          .map((h) => RomRow.fromRom(h.rom, onTap: () => _openHit(h)))
          .toList();
    }

    final romList = RomListView(
      key: ValueKey(_searchQuery),
      rows: rows,
      groups: groups,
      display: RowDisplay.roms,
      store: widget.store,
      enableSelection: true,
      onDeleteRow: (r) => _lib.deleteRom(r.filePath!),
      onRowsRemoved: (removed) =>
          _removeFromSearch(removed.map((r) => r.filePath!).toList()),
      bulkFavorites: true,
      bulkPlaylist: true,
      onRowsExcluded: _onRowsExcluded,
      onRowExcluded: (r) => _removeFromSearch([r.filePath!]),
      onPlaylistChanged: widget.onPlaylistChanged,
    );
    if (_folderHits.isEmpty) return romList;
    // Folder matches ride above the ROM results as a short, tappable list.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._folderResultTiles(),
        Expanded(child: romList),
      ],
    );
  }

  // One tappable tile per matched system folder: the console (long) name over
  // the folder (short) name, opening the folder on tap. ponytail: a plain
  // (unscrolled) list; a query rarely matches more than a handful of systems.
  List<Widget> _folderResultTiles() => [
        for (final s in _folderHits)
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_open),
            title: Text(ConsoleMap.nameFor(s.consoleId) ?? s.name),
            subtitle: Text('${s.name} · ${s.totalGames} '
                '${s.totalGames == 1 ? 'game' : 'games'}'),
            onTap: () => widget.onOpenFolder?.call(s.systemPath),
          ),
      ];

  // Drops rows from results AND the persisted index so removal sticks
  // across the next keystroke.
  Future<void> _removeFromSearch(List<String> paths) async {
    final removed =
        _searchHits.where((h) => paths.contains(h.rom.filePath)).toList();
    if (mounted) {
      setState(() =>
          _searchHits.removeWhere((h) => paths.contains(h.rom.filePath)));
    }
    await _dropFromIndex(removed);
  }

  // Rewrites each affected system's file with the paths removed.
  Future<void> _dropFromIndex(List<SearchHit> removed) async {
    final bySystem = <String, Set<String>>{};
    for (final h in removed) {
      bySystem.putIfAbsent(h.systemPath, () => {}).add(h.rom.filePath);
    }
    for (final entry in bySystem.entries) {
      final data = await _lib.load(entry.key);
      final games =
          data.games.where((g) => !entry.value.contains(g.filePath)).toList();
      final consoleId = await ScanSettings.consoleIdForFolder(entry.key);
      await _lib.save(data.copyWith(games: games, consoleId: consoleId));
    }
  }

  Future<void> _onRowsExcluded(List<RomRow> rows) async {
    final paths = [for (final r in rows) r.filePath!];
    await _removeFromSearch(paths);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Excluded ${paths.length} '
          'file${paths.length == 1 ? '' : 's'}')),
    );
  }

  // Index rows are lightweight; load the system file for full game info.
  Future<void> _openHit(SearchHit hit) async {
    final rom = hit.rom;
    final data = await _lib.load(hit.systemPath);
    final entry =
        data.games.where((g) => g.filePath == rom.filePath).firstOrNull;
    if (entry?.gameInfo != null) {
      applyGameInfo(rom, entry!.gameInfo);
      rom.earnedAchievements = entry.progress?.earnedAchievements;
      rom.lastPlayed = entry.progress?.lastPlayed;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => GameDetailDialog(
        rom: rom,
        store: widget.store,
        onPlaylistChanged: widget.onPlaylistChanged,
        // Search has no hashing pipeline, so only an already-matched game can
        // be refreshed from here; null keeps the button hidden for the rest.
        onFetch: rom.gameId == null ? null : () => _syncProgress(hit),
        scraped: ScrapedStore.instance.get(rom.filePath),
      ),
    );
  }

  // The matched half of the folder view's fetch: re-pull one game's info and
  // progress and write it back to its system file.
  Future<void> _syncProgress(SearchHit hit) async {
    final gameId = hit.rom.gameId;
    if (gameId == null) return;
    final credentials = await requireCredentials(context);
    if (credentials == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (info, progress) =
          await RaService(username: credentials.$1, apiKey: credentials.$2)
              .getGameInfoAndUserProgress(gameId);
      final data = await _lib.load(hit.systemPath);
      await _lib.save(data.copyWith(games: [
        for (final g in data.games)
          g.filePath == hit.rom.filePath
              ? g.copyWith(
                  gameInfo: info,
                  progress: progress,
                  lastScanned: DateTime.now())
              : g,
      ]));
      if (!mounted) return;
      setState(() {
        applyGameInfo(hit.rom, info);
        hit.rom.earnedAchievements = progress.earnedAchievements;
        hit.rom.earnedHardcore = progress.earnedHardcore;
        hit.rom.highestAward = progress.highestAward;
        hit.rom.highestAwardDate = progress.highestAwardDate;
        hit.rom.lastPlayed = progress.lastPlayed;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Progress synced')));
    } catch (e) {
      LogService.error('HomeSearch/syncProgress', 'game $gameId: $e');
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Failed to sync progress: $e')));
      }
    }
  }
}
