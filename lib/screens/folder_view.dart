import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rom_result.dart';
import '../services/duplicate_finder.dart';
import '../services/fetch_engine.dart';
import '../services/fetch_pipeline.dart';
import '../services/credentials.dart';
import '../services/game_lookup.dart';
import '../services/log_service.dart';
import '../services/metadata_cache.dart';
import '../services/metadata_fetch.dart';
import '../services/ra_cache.dart';
import '../services/ra_service.dart';
import '../services/scan_settings.dart';
import '../services/console_map.dart';
import '../services/library.dart';
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
import '../models/folder_sort.dart';
import '../models/rom_row.dart';
import '../models/rom_group.dart';
import '../widgets/android_disc_hashing_dialog.dart';
import '../widgets/folder_toolbar.dart';
import '../widgets/fetch_tasks_dialog.dart';
import '../widgets/game_detail_dialog.dart';
import '../widgets/row_display.dart';
import '../widgets/require_credentials.dart';
import '../widgets/rom_list_view.dart';
import '../theme/ui_tokens.dart';


const _groupColors = [
  Color(0xFF7986CB),
  Color(0xFFEF9A9A),
  Color(0xFF80CBC4),
  Color(0xFFFFCC80),
  Color(0xFF80DEEA),
];

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
  CleanupScoreMode _cleanupMode = CleanupScoreMode.logDampened;
  // Sort override; a flag (not a FolderSort) so toggling off restores the
  // previous sort.
  bool _hot = false;
  bool _fetching = false;
  int _checked = 0;
  int _toCheck = 0;

  List<String> get _availableGenres => availableGenres(_roms);
  List<String> get _availableTags => availableTags(_roms);
  List<RomResult> get _visibleRoms => visibleRoms(_roms, _filter, _membership);

  // Nulls always sink to the bottom regardless of direction.
  static int _nullsLast<T extends Comparable<Object>>(T? a, T? b, int dir) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return dir * a.compareTo(b);
  }

  List<RomResult> get _sortedRoms {
    final list = _visibleRoms;
    if (_hot) {
      list.sort((a, b) =>
          (b.numPlayersCasual ?? 0).compareTo(a.numPlayersCasual ?? 0));
      return list;
    }
    final dir = _sortAscending ? 1 : -1;
    switch (_folderSort) {
      case FolderSort.alphabetical:
        list.sort((a, b) =>
            dir *
            a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
      case FolderSort.achievementCount:
        list.sort(
            (a, b) => _nullsLast(a.achievementCount, b.achievementCount, dir));
      case FolderSort.points:
        list.sort((a, b) => _nullsLast(a.points, b.points, dir));
      case FolderSort.progress:
        double? ratio(RomResult r) => (r.achievementCount ?? 0) > 0
            ? (r.earnedAchievements ?? 0) / r.achievementCount!
            : null;
        list.sort((a, b) => _nullsLast(ratio(a), ratio(b), dir));
      case FolderSort.lastPlayed:
        list.sort((a, b) => _nullsLast(a.lastPlayed, b.lastPlayed, dir));
      case FolderSort.cleanup:
        double? cleanup(RomResult r) => cleanupScore(
              players: r.numPlayersCasual ?? 0,
              setCreated: r.setCreated,
              mode: _cleanupMode,
            );
        list.sort((a, b) => _nullsLast(cleanup(a), cleanup(b), dir));
    }
    return list;
  }

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
    final v = FolderSort.values.asNameMap()[prefs.getString(PrefKeys.folderSort)];
    final asc = prefs.getBool(PrefKeys.folderSortAsc) ?? true;
    final grid = prefs.getBool(PrefKeys.folderGridView) ?? false;
    final mode = CleanupScoreMode.values
        .asNameMap()[prefs.getString(PrefKeys.cleanupMode)];
    if (mounted) {
      setState(() {
        if (v != null) _folderSort = v;
        _sortAscending = asc;
        _gridView = grid;
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
    final files = await listRomFiles(widget.folderPaths, widget.enabledExtensions);

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
    _raSupported = widget.folderPaths
        .any((path) => ConsoleMap.isRaSupported(consoleIdByPath[path]));

    // A display-only folder is still fetchable if a third-party metadata
    // provider is configured and supports its console.
    if (!_raSupported) {
      final provider = await savedMetadataProvider();
      _metadataFetchable = provider != null &&
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
      games.add(GameEntry(
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
              ),
      ));
    }
    final consoleId = widget.consoleId ??
        await ScanSettings.consoleIdForFolder(systemPath);
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
    final plan = await showFetchTasksDialog(context, global: false);
    if (plan == null || !mounted) return;
    if (plan.refresh) await _refreshFiles();
    if (plan.match) {
      await _fetch(onlyUnfetched: !plan.matchReFetchAll);
    }
    if (plan.progress && !plan.match) await _syncFolderProgress();
  }

  Future<void> _fetch({required bool onlyUnfetched}) async {
    final consoleId = await _resolveConsoleId();
    if (consoleId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Unknown console for this folder. Set it in Settings → System mapping.')));
      return;
    }

    // Display-only systems have no RA hash. Fetch game metadata by name from
    // the configured third-party provider instead.
    if (!ConsoleMap.isRaSupported(consoleId)) {
      await _fetchMetadata(consoleId, onlyUnfetched: onlyUnfetched);
      return;
    }

    if (!mounted) return;
    final credentials = await requireCredentials(context);
    if (credentials == null) return;
    final (username, apiKey) = credentials;
    final service = RaService(username: username, apiKey: apiKey);
    final raCache = RaCache();
    final byPath = {for (final r in _roms) r.filePath: r};
    final targets = onlyUnfetched
        ? _roms
            .where((r) => r.status == RomStatus.notFetched)
            .map((r) => r.filePath)
            .toList()
        : _roms.map((r) => r.filePath).toList();

    final dolphinToolPath = await DiscDecompressor.resolveToolPath();

    // Without a decompressor tool, compressed discs can't be hashed; mark and skip.
    final unhashable = dolphinToolPath == null
        ? targets.where((path) => DiscFormats.needsDecompression(path)).toList()
        : <String>[];
    if (unhashable.isNotEmpty) {
      setState(() {
        for (final path in unhashable) {
          byPath[path]?.status = RomStatus.unsupportedFormat;
        }
      });
      targets.removeWhere(unhashable.contains);
      // On Android the tool is never present, so this is always a GC/Wii
      // compressed dump; tell the user it can't be matched yet.
      if (Platform.isAndroid && mounted) {
        await showAndroidDiscHashingUnsupported(context);
      }
    }

    setState(() {
      _fetching = true;
      _checked = 0;
      _toCheck = targets.length;
      for (final path in targets) {
        byPath[path]?.status = RomStatus.checking;
      }
    });

    final detailCache = <int, (GameInfo, UserProgress)>{};
    // Saved entries by path so a rescan reuses rich info without network calls.
    final savedByPath = <String, GameEntry>{
      for (final data in _systemData.values)
        for (final g in data.games)
          if (g.gameInfo != null) g.filePath: g,
    };

    final engine = FetchEngine(
      hash: romHasher(
          consoleId: consoleId,
          dolphinToolPath: dolphinToolPath,
          logContext: 'FolderView/hash'),
      lookupGameId: (md5) => raCache.resolveGameId(service, consoleId, md5),
      onResult: (res) async {
        final rom = byPath[res.filePath];
        if (rom == null) return;
        await applyFetchResultToRom(
          res: res,
          rom: rom,
          consoleId: consoleId,
          service: service,
          raCache: raCache,
          detailCache: detailCache,
          saved: savedByPath[res.filePath],
          logContext: 'FolderView/fetch',
          mutate: (fn) {
            if (mounted) setState(fn);
          },
        );
        if (mounted) setState(() => _checked++);
      },
    );

    LogService.info('FolderView/fetch',
        'Fetching ${targets.length} ROMs in ${widget.title} '
        '(onlyUnfetched=$onlyUnfetched)');
    await engine.run(targets);

    if (mounted) {
      assignDuplicateGroups(_roms);
      _applyDismissalsFromData(_roms);
      setState(() => _fetching = false);
    }
    await _persistAll();
  }

  // Name-based metadata fetch for a display-only (non-RA) console.
  Future<void> _fetchMetadata(int consoleId,
      {required bool onlyUnfetched}) async {
    final provider = await savedMetadataProvider();
    if (provider == null || !provider.supports(consoleId)) {
      if (!mounted) return;
      final name = ConsoleMap.nameFor(consoleId) ?? 'This system';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider == null
              ? "$name isn't on RetroAchievements. Add a metadata source in "
                  'Settings to fetch game info.'
              : "$name isn't supported by the selected metadata source.")));
      return;
    }

    final byPath = {for (final r in _roms) r.filePath: r};
    // onlyUnfetched still re-queries no-match rows (they stay localOnly);
    // a full re-fetch redoes everything.
    final targets = _roms
        .where((r) => !onlyUnfetched || r.status == RomStatus.localOnly)
        .map((r) => r.filePath)
        .toList();
    if (targets.isEmpty) return;

    setState(() {
      _fetching = true;
      _checked = 0;
      _toCheck = targets.length;
      for (final path in targets) {
        byPath[path]?.status = RomStatus.checking;
      }
    });

    await runMetadataFetch(
      files: targets,
      consoleId: consoleId,
      provider: provider,
      cache: MetadataCache(),
      onResult: (path, meta) {
        final rom = byPath[path];
        if (rom == null || !mounted) return;
        setState(() {
          applyMetadata(rom, meta);
          _checked++;
        });
      },
    );

    if (mounted) setState(() => _fetching = false);
    await _persistAll();
  }

  // Re-walks the folder; new files show as not-fetched, removed drop out.
  Future<void> _refreshFiles() async {
    final files =
        await listRomFiles(widget.folderPaths, widget.enabledExtensions);

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

  Future<void> _syncFolderProgress() async {
    final credentials = await requireCredentials(context);
    if (credentials == null) return;

    final targets = _roms.where((r) => r.gameId != null).toList();
    if (targets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matched games to sync.')),
      );
      return;
    }

    final (username, apiKey) = credentials;
    final service = RaService(username: username, apiKey: apiKey);

    setState(() {
      _fetching = true;
      _checked = 0;
      _toCheck = targets.length;
    });

    // One sweep instead of per-game GETs; guards skip the write on
    // failure/empty so progress is never zeroed.
    final sweep =
        await fetchCompletionSweep(service, 'FolderView/syncProgress');
    final byGameId = sweep.byGameId;
    if (byGameId == null) {
      if (mounted) {
        setState(() => _fetching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sweep.userMessage!)),
        );
      }
      return;
    }

    // Pure in-memory update, one rebuild for the whole batch.
    for (final rom in targets) {
      final prog = byGameId[rom.gameId!];
      rom.earnedAchievements = prog?.numAwarded ?? 0;
      rom.earnedHardcore = prog?.numAwardedHardcore ?? 0;
      rom.lastPlayed = prog?.lastPlayed;
    }
    if (mounted) {
      setState(() {
        _checked = targets.length;
        _fetching = false;
      });
    }
    await _persistAll();
  }

  Future<void> _fetchSingleRom(RomResult rom) async {
    final credentials = await requireCredentials(context);
    if (credentials == null) return;

    final (username, apiKey) = credentials;
    final service = RaService(username: username, apiKey: apiKey);

    // Already matched, just refresh progress.
    if (rom.gameId != null) {
      try {
        final (info, progress) =
            await service.getGameInfoAndUserProgress(rom.gameId!);
        if (mounted) {
          setState(() {
            applyGameInfo(rom, info);
            rom.earnedAchievements = progress.earnedAchievements;
            rom.earnedHardcore = progress.earnedHardcore;
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
          orElse: () => widget.folderPaths.first);
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
            content: Text(name != null
                ? '$name is not supported by RetroAchievements.'
                : 'Unknown console for this folder.')),
      );
      return;
    }

    final dolphinToolPath = await DiscDecompressor.resolveToolPath();

    if (DiscFormats.needsDecompression(rom.filePath) &&
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
          logContext: 'FolderView/fetchSingle'),
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
        orElse: () => widget.folderPaths.first);
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
        content: Text('Excluded $n file${n == 1 ? '' : 's'}. Manage in Settings.'),
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
      title: gameDisplayName(rep.gameTitle, stripDiscToken(rep.fileName)),
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
        while (i < roms.length && roms[i].duplicateGroupId == gid) { i++; }
        final end = i;
        final color = _groupColors[gid % _groupColors.length];
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
    return Scaffold(
      backgroundColor: ui.surface,
      appBar: AppBar(
        backgroundColor: ui.surface,
        title: Text(widget.title),
        bottom: _fetching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _toCheck == 0 ? null : _checked / _toCheck,
                ),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                FolderToolbar(
                  filter: _filter,
                  sort: _folderSort,
                  sortAscending: _sortAscending,
                  gridView: _gridView,
                  availableGenres: _availableGenres,
                  availableTags: _availableTags,
                  showProgress: _anyProgress,
                  anyDuplicates: _anyDuplicates,
                  hot: _hot,
                  showHot: _roms.any((r) => (r.numPlayersCasual ?? 0) > 0),
                  cleanupMode: _cleanupMode,
                  playlists: [
                    for (final pl in _playlists) (id: pl.id, name: pl.name)
                  ],
                  showActions:
                      widget.showActions && (_raSupported || _metadataFetchable),
                  actionsEnabled: !_fetching,
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
                  onDuplicatesToggle: (on) => setState(
                      () => _filter = _filter.copyWith(onlyDuplicates: on)),
                  onHotToggle: (on) => setState(() => _hot = on),
                  onRunActions: _showTaskDialog,
                ),
                Expanded(
                  child: RomListView(
                    rows: _filter.onlyDuplicates ? const [] : _listingRows(),
                    groups: _filter.onlyDuplicates ? _buildDupGroups() : null,
                    display: _filter.onlyDuplicates
                        ? RowDisplay.roms.copyWith(showDupBadge: false)
                        : RowDisplay.roms,
                    store: _playlistStore,
                    enableSelection: true,
                    gridView: _gridView,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.75),
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
                  ),
                ),
              ],
            ),
    );
  }
}
