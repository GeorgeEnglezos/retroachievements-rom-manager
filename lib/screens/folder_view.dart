import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fetch_plan.dart';
import '../models/rom_result.dart';
import '../services/duplicate_finder.dart';
import '../services/fetch_engine.dart';
import '../services/fetch_pipeline.dart';
import '../services/fetch_run.dart';
import '../services/credentials.dart';
import '../services/scan_run.dart';
import '../services/game_lookup.dart';
import '../services/log_service.dart';
import '../services/metadata_cache.dart';
import '../services/ra_cache.dart';
import '../services/ra_service.dart';
import '../services/scan_settings.dart';
import '../services/app_mode.dart';
import '../services/console_map.dart';
import '../services/library.dart';
import '../services/play_view.dart';
import '../services/playlist_store.dart';
import '../services/pref_keys.dart';
import '../services/scraper/scraped_store.dart';
import '../models/system_data.dart';
import '../models/game_entry.dart';
import '../models/user_progress.dart';
import '../services/disc_decompressor.dart';
import '../services/disc_formats.dart';
import '../services/rom_file_lister.dart';
import '../services/rom_filter.dart';
import '../services/cleanup_score.dart';
import '../services/disc_grouping.dart';
import '../services/switch_grouping.dart';
import '../models/folder_sort.dart';
import '../models/rom_row.dart';
import '../models/rom_group.dart';
import '../widgets/android_disc_hashing_dialog.dart';
import '../widgets/app_shell.dart';
import '../widgets/folder_toolbar.dart';
import '../widgets/fetch_fab.dart';
import '../widgets/fetch_tasks_dialog.dart';
import '../widgets/game_detail_dialog.dart';
import '../widgets/row_display.dart';
import '../widgets/require_credentials.dart';
import '../widgets/rom_list_view.dart';
import '../theme/ui_tokens.dart';

class _GroupHeader {
  final Color color;
  final int count;
  const _GroupHeader({required this.color, required this.count});
}

class FolderView extends StatefulWidget {
  final List<String> folderPaths;
  final String title;
  final int? consoleId;
  final Set<String> enabledExtensions;
  // Injectable for tests; defaults to the shared instance.
  final Library? library;
  // The cross-system "All games" view turns this off: fetch/hash actions are
  // unsound across mixed consoles.
  final bool showActions;

  const FolderView({
    super.key,
    required this.folderPaths,
    required this.title,
    this.consoleId,
    required this.enabledExtensions,
    this.library,
    this.showActions = true,
  });

  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  final List<RomResult> _roms = [];
  RomFilter _filter = const RomFilter();
  final PlaylistStore _playlistStore = PlaylistStore();
  late final Library _lib = widget.library ?? Library.instance;
  final Map<String, SystemData> _systemData = {};
  List<Playlist> _playlists = [];
  Map<String, Set<String>> _membership = {};
  bool _loading = true;
  // False for a single non-RA folder; hides the fetch/hash Actions button.
  bool _raSupported = true;
  // True when a display-only folder can still fetch metadata via a configured
  // third-party provider; keeps the Actions button available for it.
  bool _metadataFetchable = false;
  FolderSort _folderSort = FolderSort.alphabetical;
  bool _sortAscending = true;
  bool _gridView = false;
  // Whether the search + filters toolbar is shown. Collapsing it hands the whole
  // body to the game list, which matters most on a short landscape phone.
  bool _toolbarVisible = false;
  double _gridSize = FolderToolbar.gridSizeDefault;
  // The layout actually drawn. Play mode can pin it, in which case the toolbar
  // toggle is hidden and _gridView keeps whatever cleaning last chose.
  bool get _effectiveGrid => switch (playView.layout) {
    PlayLayout.follow => _gridView,
    PlayLayout.list => false,
    PlayLayout.grid => true,
  };
  CleanupScoreMode _cleanupMode = CleanupScoreMode.logDampened;
  // Sort override; a flag (not a FolderSort) so toggling off restores the
  // previous sort.
  bool _hot = false;

  List<String> get _availableGenres => availableGenres(_roms);
  List<String> get _availableTags => availableTags(_roms);
  List<RomResult> get _visibleRoms => visibleRoms(_roms, _filter, _membership);

  List<RomResult> get _sortedRoms => sortRoms(
    _visibleRoms,
    sort: _folderSort,
    ascending: _sortAscending,
    hot: _hot,
    cleanupMode: _cleanupMode,
  );

  bool get _anyDuplicates => _roms.any((r) => r.duplicateGroupId != null);
  bool get _anyProgress => _roms.any((r) => r.earnedAchievements != null);

  // Applies the dismissed-duplicate pairs stored in each system's file.
  void _applyDismissalsFromData(List<RomResult> roms) {
    final pairs = <String>{};
    for (final data in _systemData.values) {
      pairs.addAll(data.dismissedDuplicatePairs);
    }
    bool dismissed(String a, String b) => pairs.contains(_pairKey(a, b));
    final byGroup = <int, List<RomResult>>{};
    for (final r in roms) {
      if (r.duplicateGroupId != null) {
        byGroup.putIfAbsent(r.duplicateGroupId!, () => []).add(r);
      }
    }
    for (final group in byGroup.values) {
      for (final r in group) {
        final others = group.where((o) => o != r);
        if (others.every((o) => dismissed(r.filePath, o.filePath))) {
          r.duplicateGroupId = null;
        }
      }
    }
  }

  // Dismisses the ROM's pairing with every other group member.
  Future<void> _onDismissSingle(RomResult rom) async {
    if (rom.duplicateGroupId == null) return;
    final others = _roms
        .where((r) => r != rom && r.duplicateGroupId == rom.duplicateGroupId)
        .map((r) => r.filePath);
    _addDismissedPairs([for (final o in others) _pairKey(rom.filePath, o)]);
    await _persistAndReapplyDismissals();
  }

  String _pairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }

  void _addDismissedPairs(List<String> keys) {
    for (final sysPath in widget.folderPaths) {
      final data = _systemData[sysPath];
      if (data == null) continue;
      for (final k in keys) {
        final parts = k.split('|');
        if (parts.every((path) => p.isWithin(sysPath, path))) {
          data.dismissedDuplicatePairs.add(k);
        }
      }
    }
  }

  Future<void> _persistAll() async {
    for (final sysPath in widget.folderPaths) {
      await _persistSystem(sysPath);
    }
  }

  Future<void> _persistAndReapplyDismissals() async {
    assignDuplicateGroups(_roms);
    _applyDismissalsFromData(_roms);
    await _persistAll();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadPersisted();
    _loadPlaylists();
    _loadSortPref();
  }

  Future<void> _loadSortPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = FolderSort.values
        .asNameMap()[prefs.getString(PrefKeys.folderSort)];
    final asc = prefs.getBool(PrefKeys.folderSortAsc) ?? true;
    final grid = prefs.getBool(PrefKeys.folderGridView) ?? false;
    final size =
        prefs.getDouble(PrefKeys.folderGridSize) ??
        FolderToolbar.gridSizeDefault;
    final mode = CleanupScoreMode.values
        .asNameMap()[prefs.getString(PrefKeys.cleanupMode)];
    if (mounted) {
      setState(() {
        if (v != null) _folderSort = v;
        _sortAscending = asc;
        _gridView = grid;
        _gridSize = size.clamp(
          FolderToolbar.gridSizeMin,
          FolderToolbar.gridSizeMax,
        );
        if (mode != null) _cleanupMode = mode;
      });
    }
  }

  Future<void> _loadPlaylists() async {
    _playlists = await _playlistStore.all();
    _membership = playlistMembership(_playlists);
    if (mounted) setState(() {});
  }

  // Passed-in id (combined views) or resolved from the folder name/override.
  Future<int?> _resolveConsoleId() async =>
      widget.consoleId ??
      await ScanSettings.consoleIdForFolder(widget.folderPaths.first);

  // One file read per system; the directory is still listed so outside
  // changes surface.
  Future<void> _loadPersisted() async {
    final files = await listRomFiles(
      widget.folderPaths,
      widget.enabledExtensions,
    );

    final entryByPath = <String, GameEntry>{};
    final consoleIdByPath = <String, int?>{};
    for (final sysPath in widget.folderPaths) {
      final data = await _lib.load(sysPath);
      _systemData[sysPath] = data;
      consoleIdByPath[sysPath] =
          widget.consoleId ?? await ScanSettings.consoleIdForFolder(sysPath);
      for (final g in data.games) {
        entryByPath[g.filePath] = g;
      }
    }

    // If no folder in this view is on RA, nothing here can be fetched. Hide the
    // Actions button. (Mixed views keep it: some ROMs are still fetchable.)
    _raSupported = widget.folderPaths.any(
      (path) => ConsoleMap.isRaSupported(consoleIdByPath[path]),
    );

    // A display-only folder is still fetchable if a third-party metadata
    // provider is configured and supports its console.
    if (!_raSupported) {
      final provider = await savedMetadataProvider();
      _metadataFetchable =
          provider != null &&
          widget.folderPaths.any((path) {
            final id = consoleIdByPath[path];
            return id != null && provider.supports(id);
          });
    }

    // Each game's stale-hash check uses its own folder's current console, so a
    // mixed-console view ("All games") doesn't judge every game by one console
    // and mislabel other systems' unsupported games as not-fetched.
    int? consoleForFile(String path) {
      for (final sysPath in widget.folderPaths) {
        if (p.isWithin(sysPath, path)) return consoleIdByPath[sysPath];
      }
      return widget.consoleId;
    }

    final roms = <RomResult>[];
    for (final f in files) {
      final entry = entryByPath[f.path];
      final fileConsoleId = consoleForFile(f.path);
      final rom = entry == null
          ? (RomResult(filePath: f.path, fileName: p.basename(f.path))
              ..consoleId = fileConsoleId
              ..consoleName = ConsoleMap.nameFor(fileConsoleId)
              ..status = ConsoleMap.isRaSupported(fileConsoleId)
                  ? RomStatus.notFetched
                  : RomStatus.localOnly)
          : romFromEntry(entry, consoleId: fileConsoleId);
      rom.fileSize = f.size; // listing is fresher than the persisted size
      roms.add(rom);
    }
    assignDuplicateGroups(roms);
    _applyDismissalsFromData(roms);
    if (!mounted) return;
    setState(() {
      _roms
        ..clear()
        ..addAll(roms);
      _loading = false;
    });
  }

  // Rebuilds a system's file from the in-memory _roms and updates the index.
  Future<void> _persistSystem(String systemPath) async {
    final existing = _systemData[systemPath];
    final games = <GameEntry>[];
    for (final r in _roms.where((r) => p.isWithin(systemPath, r.filePath))) {
      games.add(
        GameEntry(
          filePath: r.filePath,
          fileName: r.fileName,
          fileSize: r.fileSize,
          md5: r.md5Hash,
          gameId: r.gameId,
          matched: r.status == RomStatus.supported,
          noMatch: r.status == RomStatus.unsupported,
          lastScanned: DateTime.now(),
          hashConsoleId: r.hashConsoleId,
          metadata: r.metadata,
          gameInfo: _romToGameInfo(r),
          progress: r.earnedAchievements == null
              ? null
              : UserProgress(
                  gameId: r.gameId ?? 0,
                  earnedAchievements: r.earnedAchievements!,
                  earnedHardcore: r.earnedHardcore ?? 0,
                  lastPlayed: r.lastPlayed,
                  highestAward: r.highestAward ?? RaAward.none,
                  highestAwardDate: r.highestAwardDate,
                ),
        ),
      );
    }
    final consoleId =
        widget.consoleId ?? await ScanSettings.consoleIdForFolder(systemPath);
    final data = SystemData(
      systemId: existing?.systemId ?? '',
      systemPath: systemPath,
      consoleId: consoleId,
      games: games,
      dismissedDuplicatePairs: existing?.dismissedDuplicatePairs ?? <String>{},
    );
    _systemData[systemPath] = await _lib.save(data);
  }

  GameInfo? _romToGameInfo(RomResult r) {
    if (r.status != RomStatus.supported || r.gameId == null) return null;
    // A row whose detail fetch failed reads as supported but carries only the
    // "Game #id" placeholder. Persisting that as real GameInfo would bake the
    // placeholder in: later scans would treat the entry as resolved and reuse
    // it forever. Leave it null so a rescan still fetches the real thing.
    if (r.achievementCount == null) return null;
    return GameInfo(
      gameId: r.gameId!,
      title: r.gameTitle ?? '',
      consoleName: r.consoleName ?? '',
      consoleId: r.consoleId,
      achievementCount: r.achievementCount ?? 0,
      imageIcon: r.imageIcon,
      imageBoxArt: r.imageBoxArt,
      imageTitle: r.imageTitle,
      imageIngame: r.imageIngame,
      publisher: r.publisher,
      developer: r.developer,
      genre: r.genre,
      released: r.released,
      points: r.points,
      numPlayersCasual: r.numPlayersCasual ?? 0,
      numPlayersHardcore: r.numPlayersHardcore ?? 0,
    );
  }

  Future<void> _showTaskDialog() async {
    // The home sweep may already own the bar; a second run would write the same
    // SystemData from under it. The FAB disables on this too, but the dialog can
    // outlive the press that opened it.
    if (ScanRun.busy) return;
    final plan = await showFetchTasksDialog(context, global: false);
    if (plan == null || !mounted) return;
    // Phase one, local and free: pick up files added or removed since the last
    // run so the scan below sees them.
    if (plan.refresh) {
      await _refreshFiles();
      if (!mounted) return;
    }
    await _runFetch(plan);
  }

  // One shared run across every folder this view covers. The runner owns
  // persistence, so nothing here calls _persistAll afterwards.
  Future<void> _runFetch(FetchPlan plan) async {
    final consoleId = await _resolveConsoleId();
    if (consoleId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unknown console for this folder. Set it in Settings → System mapping.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    RaService? service;
    if (ConsoleMap.isRaSupported(consoleId)) {
      final credentials = await requireCredentials(context);
      if (credentials == null) return;
      service = RaService(username: credentials.$1, apiKey: credentials.$2);
    }
    if (!mounted) return;

    final metadataProvider = await savedMetadataProvider();

    // Nothing here is fetchable. Say why, rather than starting a run that does
    // no work and ends without a word.
    if (!ConsoleMap.isRaSupported(consoleId) &&
        (metadataProvider == null || !metadataProvider.supports(consoleId))) {
      if (!mounted) return;
      final name = ConsoleMap.nameFor(consoleId) ?? 'This system';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            metadataProvider == null
                ? "$name isn't on RetroAchievements. Add a metadata source in "
                      'Settings to fetch game info.'
                : "$name isn't supported by the selected metadata source.",
          ),
        ),
      );
      return;
    }
    // A progress-only pass over rows that were never matched has nothing to
    // write; the sweep would burn an API call for no change.
    if (plan.progress && !plan.match && _roms.every((r) => r.gameId == null)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matched games to sync.')),
      );
      return;
    }

    final raCache = RaCache();
    final detailCache = <int, (GameInfo, UserProgress)>{};
    final byPath = {for (final r in _roms) r.filePath: r};

    final run = ScanRun();
    run.start(label: widget.title);

    try {
      // One account-wide sweep for the run, shared with every folder below.
      // Null when it failed, which tells the runner to leave stored progress
      // alone rather than write zeros over it.
      Map<int, CompletedGame>? progressByGameId;
      if (plan.progress && service != null) {
        final sweep = await fetchCompletionSweep(service, 'FolderView/fetch');
        progressByGameId = sweep.byGameId;
        if (!mounted) return;
        if (sweep.userMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(sweep.userMessage!)));
        }
      }

      for (final sysPath in widget.folderPaths) {
        if (!mounted || run.cancelled) break;
        // Each folder is mapped on its own, so a combined view maps every row
        // against its own system rather than the first folder's.
        final folderConsoleId =
            widget.consoleId ?? await ScanSettings.consoleIdForFolder(sysPath);
        final result = await runFolderFetch(
          folderPath: sysPath,
          plan: plan,
          extensions: widget.enabledExtensions,
          library: _lib,
          run: run,
          raCache: raCache,
          detailCache: detailCache,
          service: service,
          consoleId: widget.consoleId,
          metadataProvider: metadataProvider,
          metadataCache: MetadataCache(),
          progressByGameId: progressByGameId,
          logContext: 'FolderView/fetch',
          onTargets: run.addTotal,
          onEntry: (entry) {
            if (!mounted) return;
            final rom = byPath[entry.filePath];
            if (rom == null) return;
            final fresh = romFromEntry(entry, consoleId: folderConsoleId);
            setState(() {
              final i = _roms.indexOf(rom);
              if (i != -1) _roms[i] = fresh;
              byPath[entry.filePath] = fresh;
            });
          },
        );
        _systemData[sysPath] = result.saved;

        // Compressed discs with no decompressor can never be hashed; say so on
        // the row rather than leaving them looking unscanned.
        for (final path in result.unhashable) {
          byPath[path]?.status = RomStatus.unsupportedFormat;
        }
        // On Android the decompressor is never present, so this is always a
        // compressed GC/Wii dump; tell the user it cannot be matched yet.
        if (result.unhashable.isNotEmpty && Platform.isAndroid && mounted) {
          await showAndroidDiscHashingUnsupported(context);
        }
      }
    } finally {
      run.stop();
      if (mounted) {
        assignDuplicateGroups(_roms);
        _applyDismissalsFromData(_roms);
        setState(() {});
      }
    }
  }

  // Re-walks the folder; new files show as not-fetched, removed drop out.
  Future<void> _refreshFiles() async {
    final files = await listRomFiles(
      widget.folderPaths,
      widget.enabledExtensions,
    );

    final existingPaths = {for (final r in _roms) r.filePath};
    final newPaths = {for (final f in files) f.path};

    final added = <RomResult>[];
    for (final f in files) {
      if (existingPaths.contains(f.path)) continue;
      final rom = RomResult(filePath: f.path, fileName: p.basename(f.path));
      rom.fileSize = f.size;
      rom.status = RomStatus.notFetched;
      added.add(rom);
    }
    final anyRemoved = _roms.any((r) => !newPaths.contains(r.filePath));

    if (!mounted) return;
    setState(() {
      _roms.removeWhere((r) => !newPaths.contains(r.filePath));
      _roms.addAll(added);
      assignDuplicateGroups(_roms);
      _applyDismissalsFromData(_roms);
    });
    if (anyRemoved || added.isNotEmpty) await _persistAll();
  }

  Future<void> _fetchSingleRom(RomResult rom) async {
    final credentials = await requireCredentials(context);
    if (credentials == null) return;

    final (username, apiKey) = credentials;
    final service = RaService(username: username, apiKey: apiKey);

    // Already matched, just refresh progress.
    if (rom.gameId != null) {
      try {
        final (info, progress) = await service.getGameInfoAndUserProgress(
          rom.gameId!,
        );
        if (mounted) {
          setState(() {
            applyGameInfo(rom, info);
            rom.earnedAchievements = progress.earnedAchievements;
            rom.earnedHardcore = progress.earnedHardcore;
            rom.highestAward = progress.highestAward;
            rom.highestAwardDate = progress.highestAwardDate;
            rom.lastPlayed = progress.lastPlayed;
          });
        }
      } catch (e) {
        LogService.error('FolderView/fetchSingle', 'game ${rom.gameId}: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sync progress: $e')),
          );
        }
      }
      final sysPathEarly = widget.folderPaths.firstWhere(
        (s) => p.isWithin(s, rom.filePath),
        orElse: () => widget.folderPaths.first,
      );
      await _persistSystem(sysPathEarly);
      return;
    }

    // Not matched yet, run full hash + lookup + progress pipeline.
    final consoleId = await _resolveConsoleId();
    if (consoleId == null || !ConsoleMap.isRaSupported(consoleId)) {
      if (!mounted) return;
      final name = ConsoleMap.nameFor(consoleId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            name != null
                ? '$name is not supported by RetroAchievements.'
                : 'Unknown console for this folder.',
          ),
        ),
      );
      return;
    }

    final dolphinToolPath = await DiscDecompressor.resolveToolPath();

    if (DiscFormats.requiresDolphinTool(rom.filePath) &&
        dolphinToolPath == null) {
      if (mounted) {
        setState(() => rom.status = RomStatus.unsupportedFormat);
        if (Platform.isAndroid) {
          await showAndroidDiscHashingUnsupported(context);
        }
      }
      return;
    }

    if (mounted) setState(() => rom.status = RomStatus.checking);

    final raCache = RaCache();
    final engine = FetchEngine(
      hash: romHasher(
        consoleId: consoleId,
        dolphinToolPath: dolphinToolPath,
        logContext: 'FolderView/fetchSingle',
      ),
      lookupGameId: (md5) => raCache.resolveGameId(service, consoleId, md5),
      onResult: (res) async {
        // Reuse persisted rich info; network only the first time.
        final saved = _systemData.values
            .expand((d) => d.games)
            .where((g) => g.filePath == rom.filePath && g.gameInfo != null)
            .firstOrNull;
        await applyFetchResultToRom(
          res: res,
          rom: rom,
          consoleId: consoleId,
          service: service,
          raCache: raCache,
          detailCache: {},
          saved: saved,
          logContext: 'FolderView/fetchSingle',
          mutate: (fn) {
            if (mounted) setState(fn);
          },
        );
      },
    );

    await engine.run([rom.filePath]);
    final sysPath = widget.folderPaths.firstWhere(
      (s) => p.isWithin(s, rom.filePath),
      orElse: () => widget.folderPaths.first,
    );
    await _persistSystem(sysPath);
  }

  // Every file a listing row stands for: all discs of a group, else the one
  // file. Group-wide delete/exclude act on the whole set.
  List<String> _pathsOf(RomRow r) => r.groupPaths ?? [r.filePath!];

  Future<void> _onExcluded(List<String> paths) async {
    await ScanSettings.addExcludedFiles(paths);
    if (!mounted) return;
    setState(() => _roms.removeWhere((r) => paths.contains(r.filePath)));
    _showExcludeUndo(paths);
  }

  void _showExcludeUndo(List<String> paths) {
    final n = paths.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Excluded $n file${n == 1 ? '' : 's'}. Manage in Settings.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final path in paths) {
              await ScanSettings.removeExcludedFile(path);
            }
            await _refreshFiles();
          },
        ),
      ),
    );
  }

  RomRow _toRow(RomResult rom) =>
      RomRow.fromRom(rom, scoreLabel: _cleanupScoreLabel(rom));

  // Collapses multi-disc sets into a single listing row; other files map 1:1.
  List<RomRow> _listingRows() =>
      groupDiscs(_sortedRoms).map(_groupToRow).toList();

  RomRow _groupToRow(DiscGroup g) {
    if (!g.isMultiDisc) return _toRow(g.discs.first);
    final rep = g.representative;
    return RomRow(
      // A Switch title has no RA match to name it, and its filename is mostly
      // bracketed title id / version, so the group row uses the cleaned name.
      title: g.switchTitle
          ? switchDisplayTitle(rep.fileName)
          : listingTitle(rep.gameTitle, stripDiscToken(rep.fileName)),
      filePath: rep.filePath,
      status: rep.status,
      imageIcon: rep.imageIcon,
      sizeBytes: g.totalSize,
      earnedAchievements: rep.earnedAchievements,
      totalAchievements: rep.achievementCount,
      rom: rep,
      discCount: g.discs.length,
      groupPaths: [for (final d in g.discs) d.filePath],
      onTap: () => _openDiscGroup(g),
      scoreLabel: _cleanupScoreLabel(rep),
    );
  }

  void _openDiscGroup(DiscGroup g) {
    showDialog(
      context: context,
      builder: (_) => GameDetailDialog(
        rom: g.representative,
        discs: g.discs,
        store: _playlistStore,
        onDeleted: _refreshFiles,
        onPlaylistChanged: _loadPlaylists,
        onFetchDisc: _fetchSingleRom,
        scraped: ScrapedStore.instance.get(g.representative.filePath),
      ),
    );
  }

  List<RomGroup> _buildDupGroups() {
    final groups = <RomGroup>[];
    RomGroup? current;
    for (final item in _groupedRows()) {
      if (item is _GroupHeader) {
        current = RomGroup(
          label: '⧉ ${item.count} COPIES',
          color: item.color,
          rows: [],
        );
        groups.add(current);
      } else {
        current?.rows.add(_toRow(item as RomResult));
      }
    }
    return groups;
  }

  List<Object> _groupedRows() {
    final roms = _visibleRoms
      ..sort((a, b) {
        final ga = a.duplicateGroupId ?? 1 << 30;
        final gb = b.duplicateGroupId ?? 1 << 30;
        if (ga != gb) return ga.compareTo(gb);
        return (a.md5Hash ?? '').compareTo(b.md5Hash ?? '');
      });
    final rows = <Object>[];
    var i = 0;
    while (i < roms.length) {
      final gid = roms[i].duplicateGroupId;
      if (gid == null) {
        rows.add(roms[i]);
        i++;
      } else {
        final start = i;
        while (i < roms.length && roms[i].duplicateGroupId == gid) {
          i++;
        }
        final end = i;
        final accents = context.ui.accents;
        final color = accents[gid % accents.length];
        rows.add(_GroupHeader(color: color, count: end - start));
        rows.addAll(roms.sublist(start, end));
      }
    }
    return rows;
  }

  // The cleanup score shown on each row while the Cleanup sort is active (both
  // score modes). Null → no label: sort isn't cleanup, or the set can't be
  // judged (no set date / inside the grace period). Lower score = more
  // deletable, matching the ascending sort.
  String? _cleanupScoreLabel(RomResult rom) {
    if (_folderSort != FolderSort.cleanup) return null;
    final score = cleanupScore(
      players: rom.numPlayersCasual ?? 0,
      setCreated: rom.setCreated,
      mode: _cleanupMode,
    );
    return score == null ? '-' : score.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    // Same gate the shell uses: an Android phone held sideways. There the top
    // AppBar costs scarce height, so its controls move to a slim left rail that
    // matches the shell's landscape rail. The system name is dropped: you
    // picked the system to get here.
    final landscapePhone = context.isLandscapePhone;
    final toggle = IconButton(
      key: const Key('toolbar_toggle'),
      icon: Icon(_toolbarVisible ? Icons.expand_less : Icons.tune),
      tooltip: _toolbarVisible
          ? 'Hide search & filters'
          : 'Show search & filters',
      onPressed: () => setState(() => _toolbarVisible = !_toolbarVisible),
    );
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_toolbarVisible)
                FolderToolbar(
                  filter: _filter,
                  sort: _folderSort,
                  sortAscending: _sortAscending,
                  gridView: _effectiveGrid,
                  showViewToggle: playView.layout == PlayLayout.follow,
                  availableGenres: _availableGenres,
                  availableTags: _availableTags,
                  showProgress: _anyProgress,
                  anyDuplicates: _anyDuplicates,
                  hot: _hot,
                  showHot: _roms.any((r) => (r.numPlayersCasual ?? 0) > 0),
                  cleanupMode: _cleanupMode,
                  playlists: [
                    for (final pl in _playlists) (id: pl.id, name: pl.name),
                  ],
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onSortChanged: (s) async {
                    setState(() => _folderSort = s);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(PrefKeys.folderSort, s.name);
                  },
                  onCleanupModeChanged: (m) async {
                    setState(() => _cleanupMode = m);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(PrefKeys.cleanupMode, m.name);
                  },
                  onDirectionToggle: () async {
                    setState(() => _sortAscending = !_sortAscending);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(PrefKeys.folderSortAsc, _sortAscending);
                  },
                  onViewToggle: () async {
                    setState(() => _gridView = !_gridView);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(PrefKeys.folderGridView, _gridView);
                  },
                  gridSize: _gridSize,
                  onGridSizeChanged: (v) => setState(() => _gridSize = v),
                  onGridSizeChangeEnd: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble(PrefKeys.folderGridSize, v);
                  },
                  onDuplicatesToggle: (on) => setState(
                    () => _filter = _filter.copyWith(onlyDuplicates: on),
                  ),
                  onHotToggle: (on) => setState(() => _hot = on),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Square covers, matching Home's shelves: derive the real
                    // column width, then size each cell to that width plus the
                    // text block so the art box comes out square at any tile
                    // size (a fixed childAspectRatio can't, since the text is a
                    // constant height while the art scales with width).
                    // A tiny margin around the grid gives popped-out edge tiles
                    // room before they clip, so its width comes off the space
                    // the column math divides up.
                    const gridPadding = EdgeInsets.all(8);
                    final gridWidth = _effectiveGrid
                        ? c.maxWidth - gridPadding.horizontal
                        : c.maxWidth;
                    final cols = gridColumns(gridWidth, _gridSize, 10);
                    final tileW = (gridWidth - 10 * (cols - 1)) / cols;
                    return RomListView(
                      rows: _filter.onlyDuplicates ? const [] : _listingRows(),
                      groups: _filter.onlyDuplicates ? _buildDupGroups() : null,
                      display: _filter.onlyDuplicates
                          ? RowDisplay.roms.copyWith(showDupBadge: false)
                          : RowDisplay.roms,
                      store: _playlistStore,
                      enableSelection: true,
                      gridView: _effectiveGrid,
                      padding: _effectiveGrid ? gridPadding : null,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        mainAxisExtent: tileW + kGridTextBlock,
                      ),
                      onDeleteRow: (r) async {
                        var any = false;
                        for (final path in _pathsOf(r)) {
                          if (await _lib.deleteRom(path)) any = true;
                        }
                        return any;
                      },
                      onRowsRemoved: (removed) => setState(() {
                        final paths = {for (final r in removed) ..._pathsOf(r)};
                        _roms.removeWhere((x) => paths.contains(x.filePath));
                      }),
                      bulkFavorites: true,
                      bulkPlaylist: true,
                      onRowsExcluded: (rows) =>
                          _onExcluded([for (final r in rows) ..._pathsOf(r)]),
                      onRowExcluded: (r) => _onExcluded(_pathsOf(r)),
                      onRowFetch: (r) => _fetchSingleRom(r.rom!),
                      onRowDismissDuplicate: (r) => _onDismissSingle(r.rom!),
                      onPlaylistChanged: _loadPlaylists,
                    );
                  },
                ),
              ),
            ],
          );
    return Scaffold(
      backgroundColor: ui.surface,
      appBar: landscapePhone
          ? null
          : AppBar(
              backgroundColor: ui.surface,
              title: Text(widget.title),
              actions: [toggle],
            ),
      body: landscapePhone
          ? SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: ui.surface,
                      border: Border(
                        right: BorderSide(
                          color: ui.border,
                          width: ui.borderWidth,
                        ),
                      ),
                    ),
                    // Scrolls if the full nav (cleaning's seven) outgrows a
                    // short landscape height.
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          toggle,
                          Divider(
                            height: 8,
                            color: ui.border,
                            thickness: ui.borderWidth,
                          ),
                          // The shell's tabs, so you can jump to any section from
                          // a system's game list. Tapping pops back to the shell
                          // and switches tabs; none is marked selected (this is
                          // a pushed route, not one of the shell's tabs).
                          for (final i in shellNavFor(appModeListenable.value))
                            ShellRailTile(
                              label: kShellDests[i].$1,
                              icon: kShellDests[i].$2,
                              selected: false,
                              onTap: () => shellNavigate?.call(i),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            )
          : content,
      floatingActionButton:
          widget.showActions && (_raSupported || _metadataFetchable)
          ? FetchFab(onPressed: _showTaskDialog)
          : null,
    );
  }
}
