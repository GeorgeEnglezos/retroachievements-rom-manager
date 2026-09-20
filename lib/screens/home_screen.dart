import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/ra_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_tokens.dart';
import '../models/fetch_plan.dart';
import '../models/folder_stats.dart';
import '../models/home_sort.dart';
import '../services/credentials.dart';
import '../services/folder_grouping.dart';
import '../services/fetch_pipeline.dart';
import '../services/fetch_run.dart';
import '../services/fetch_scope.dart';
import '../services/app_mode.dart';
import '../services/scan_run.dart';
import '../widgets/fetch_fab.dart';
import '../widgets/fetch_tasks_dialog.dart';
import 'folder_view.dart';
import '../services/log_service.dart';
import '../services/ra_cache.dart';
import '../services/ra_service.dart';
import '../services/console_map.dart';
import '../services/display_name.dart';
import '../services/favorite_systems.dart';
import '../services/library_folder.dart';
import '../widgets/pick_library_folder.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/pref_keys.dart';
import '../services/scan_settings.dart';
import '../services/settings_bus.dart';
import '../widgets/home_search.dart';
import '../services/library.dart';
import '../services/scraper/gamelist_importer.dart';
import '../services/scraper/scraped_store.dart';
import '../services/folder_freshness.dart';
import '../services/incremental_scan.dart';
import '../services/rom_file_lister.dart';
import '../models/user_progress.dart';
import '../models/game_entry.dart';
import '../widgets/folder_card.dart';
import '../widgets/ui/console_card.dart';
import '../widgets/ra_image.dart';
import '../widgets/require_credentials.dart';
import 'playlist_view.dart';
import 'scan_health_screen.dart';

/// Set by the setup wizard to ask for a full first sweep, and cleared by
/// whichever [HomeScreen] takes it.
///
/// A listenable rather than a plain flag because setup has two exits: a first
/// run installs a fresh [HomeScreen] that picks the request up as it starts,
/// while re-running from Settings returns to one that is already mounted and
/// will never run `initState` again. Top-level rather than a constructor
/// field because [AppShell] builds its bodies as a const list.
final ValueNotifier<bool> firstScanRequest = ValueNotifier(false);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlaylistStore _playlistStore = PlaylistStore();
  final Library _lib = Library.instance;
  List<Playlist> _playlists = [];

  // Member keys the library can currently show; the playlist cards count only
  // these, so a deleted game stops inflating the number.
  Set<String> _liveMemberKeys = {};
  bool _isRunning = false;
  int _checked = 0;
  String? _rootPath;
  List<Directory> _subfolders = [];
  final Map<String, FolderStats> _stats = {};

  // Titles whose RA set grew during the current sweep; summarized after it.
  final List<String> _setUpdates = [];

  // Resolved RA console id per subfolder path, used to pick its picture.
  final Map<String, int?> _folderConsoleIds = {};

  HomeSort _homeSort = HomeSort.alphabetical;
  bool get _combineSystems => combineSystemsListenable.value;
  NameMode get _nameMode => nameModeListenable.value;

  // The grid mirrors Library.summaries(), the single source of truth for which
  // systems exist: a folder shows only when it's a non-empty system there (a
  // positive stat). Ignored, missing, out-of-root, and empty systems are all
  // dropped by summaries, so they never get a stat and never show. Scans still
  // walk `_subfolders` (the raw disk list), so a folder that gains ROMs comes
  // back on the next stats load.
  List<Directory> get _presentSubfolders => [
        for (final d in _subfolders)
          if ((_stats[d.path]?.totalGames ?? 0) > 0) d
      ];

  List<Directory> get _sortedSubfolders {
    final list = List<Directory>.from(_presentSubfolders);
    list.sort((a, b) => compareByHomeSort(
          a,
          b,
          sort: _homeSort,
          name: (d) => p.basename(d.path),
          sizeBytes: (d) => _stats[d.path]?.totalSizeBytes ?? 0,
          gameCount: (d) => _stats[d.path]?.totalGames ?? 0,
          consoleId: (d) => _folderConsoleIds[d.path],
        ));
    return list;
  }

  // Folders grouped by console id; only used when _combineSystems is on.
  List<({ConsoleGroup group, FolderStats agg, String label})>
      get _combinedEntries {
    final paths = _presentSubfolders.map((d) => d.path).toList();
    final groups = groupFoldersByConsoleId(paths, _folderConsoleIds);
    final entries = groups.map((g) {
      final statsList = [
        for (final pth in g.folderPaths) _stats[pth] ?? FolderStats(path: pth)
      ];
      final agg = g.consoleId != null
          ? aggregateFolderStats(g.consoleId!, statsList)
          : statsList.first;
      final label = displayNameFor(
        mode: _nameMode,
        consoleId: g.consoleId,
        folderPaths: g.folderPaths,
      );
      return (group: g, agg: agg, label: label);
    }).toList();

    entries.sort((a, b) => compareByHomeSort(
          a,
          b,
          sort: _homeSort,
          name: (e) => e.label,
          sizeBytes: (e) => e.agg.totalSizeBytes,
          gameCount: (e) => e.agg.totalGames,
          consoleId: (e) => e.group.consoleId,
        ));
    return entries;
  }

  Set<String> _enabledExtensions = {...kDefaultRomExtensions};
  Set<String> _ignoredFolders = {};
  // Folder names pinned to the top of the grid (see FavoriteSystems).
  Set<String> _favorites = {};

  int _folderIndex = 0; // 1-based folder we're currently on
  int _folderCount = 0; // total folders in this run
  int _scanAllTotal = 0; // estimated total ROMs across all folders
  String? _currentFolder;
  ScanRun? _run;

  String _scanAllLabel() {
    final name = _currentFolder ?? '';
    final totalPart = _scanAllTotal == 0 ? '$_checked' : '$_checked/$_scanAllTotal';
    return 'System $_folderIndex/$_folderCount: $name  •  $totalPart';
  }

  // Folder card numbers, derived from what the run just saved.
  FolderStats _statsFrom(FolderRunResult result) {
    final games = result.saved.games;
    return FolderStats(
      path: result.saved.systemPath,
      totalGames: games.length,
      totalSizeBytes:
          games.fold<int>(0, (sum, g) => sum + (g.fileSize ?? 0)),
      gamesScanned: games.where((g) => g.matched || g.noMatch).length,
      gamesWithAchievements: games.where((g) => g.matched).length,
      lastScanned: result.cancelled ? null : DateTime.now(),
    );
  }

  @override
  void initState() {
    super.initState();
    settingsChanged.addListener(_onSettingsChanged);
    firstScanRequest.addListener(_consumeFirstScanRequest);
    _lib.addListener(_onLibraryChanged);
    _playlistStore.addListener(_onPlaylistsChanged);
    // Tiles read the shared scraped-data store synchronously for fallback
    // thumbnails, so Home has to repaint whenever it changes: on the initial
    // warm-up, and again after an import run from Settings or the wizard.
    // Home sits in the shell's IndexedStack, so nothing else would rebuild it.
    ScrapedStore.instance.addListener(_onScrapedChanged);
    ScrapedStore.instance.load();
    _init();
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_onSettingsChanged);
    firstScanRequest.removeListener(_consumeFirstScanRequest);
    _lib.removeListener(_onLibraryChanged);
    _playlistStore.removeListener(_onPlaylistsChanged);
    ScrapedStore.instance.removeListener(_onScrapedChanged);
    _libraryDebounce?.cancel();
    _playlistDebounce?.cancel();
    super.dispose();
  }

  void _onScrapedChanged() {
    if (mounted) setState(() {});
  }

  Timer? _libraryDebounce;
  Timer? _playlistDebounce;

  // A playlist changed somewhere else: the cull deck's verdicts, a detail
  // dialog, a bulk action. Home sits in the shell's IndexedStack, so switching
  // back to its tab never rebuilds it and the shortcut cards would keep showing
  // the counts from the last time it was visited.
  void _onPlaylistsChanged() {
    // A single action writes several times (one per key of a disc set);
    // coalesce, same as the library listener.
    _playlistDebounce = _coalesce(_playlistDebounce, _refreshPlaylists);
  }

  // One refresh per burst of notifications. A scan is excluded at both ends:
  // it feeds `_stats` live, ahead of what it has saved, and refreshes the
  // cards itself once it finishes.
  Timer? _coalesce(Timer? pending, VoidCallback refresh) {
    if (!mounted || _isRunning) return pending;
    pending?.cancel();
    return Timer(const Duration(milliseconds: 300), () {
      if (mounted && !_isRunning) refresh();
    });
  }

  // The library changed under us: a ROM deleted from the search field, a
  // dialog, another tab, or a file that vanished from disk. Waiting for a
  // screen to pop isn't enough, half of those never leave this screen, so the
  // folder cards and playlist counts would keep showing games that are gone.
  // A scan is excluded: it feeds `_stats` live, ahead of what it has saved.
  void _onLibraryChanged() {
    // One save per system arrives in a burst; coalesce.
    _libraryDebounce = _coalesce(_libraryDebounce, () {
      _loadFolderStats();
      _refreshPlaylists();
    });
  }

  // Any setting changed. Home caches the folder list, the scan filters and
  // the display flags, and the shell's IndexedStack never rebuilds it, so
  // re-read the lot rather than guessing which setting it was.
  Future<void> _onSettingsChanged() async {
    if (libraryFolderListenable.value != _rootPath) {
      _onLibraryFolderChanged(); // relists everything by itself
      return;
    }
    await _onScanFiltersChanged();
    if (mounted) setState(() {});
  }

  // A scan filter was edited (Settings, or this screen's own ignore action):
  // re-read it and refresh the folder cards.
  Future<void> _onScanFiltersChanged() async {
    final before = {..._ignoredFolders}; // copied: _loadFilters replaces it
    await _loadFilters();
    if (!mounted || _rootPath == null) return;
    // Only the ignore list changes which folders exist; for an extension or
    // excluded-file edit the counts are enough, and relisting would blank
    // every card's stats for nothing.
    if (setEquals(before, _ignoredFolders)) {
      _loadFolderStats();
    } else {
      _loadSubfolders(_rootPath!);
    }
  }

  void _onLibraryFolderChanged() {
    final path = libraryFolderListenable.value;
    if (path == _rootPath) return;
    setState(() => _rootPath = path);
    if (path != null) {
      _loadSubfolders(path);
    } else {
      setState(() {
        _subfolders = [];
        _stats.clear();
        _folderConsoleIds.clear();
      });
    }
  }

  Future<void> _init() async {
    await _loadFilters();
    _favorites = await FavoriteSystems.all();
    await _loadHomeSortPref();
    await _loadUsername();
    await _restoreLastFolder();
    await _refreshPlaylists();
    await _refreshOnBoot();

    // Covers a request made before this screen existed (the first-run exit);
    // a request made while it is already mounted arrives via the listener.
    _consumeFirstScanRequest();
  }

  // One-shot handoff from the setup wizard: a full first sweep, no dialog.
  // `progress` is explicit: matching no longer pulls each game's progress
  // itself, so without it a first scan would show a library at zero for an
  // account that has been playing for years.
  Future<void> _consumeFirstScanRequest() async {
    if (!firstScanRequest.value) return;
    firstScanRequest.value = false;
    if (!mounted) return;
    await _scanAllSystems(
      plan: const FetchPlan(
          scope: FetchScope.all, match: true, progress: true),
    );
  }

  // Async lister (same filtering as the scan) so the walk doesn't freeze the UI.
  Future<Map<String, int>> _currentSizesFor(String systemPath) async {
    final files = await listRomFiles([systemPath], _enabledExtensions);
    return {for (final f in files) f.path: f.size};
  }

  // On boot: hide gone folders, silently re-walk file lists, and offer a
  // fetch if new files turned up.
  Future<void> _refreshOnBoot() async {
    await _lib.refreshMissingSystems();
    final diff = await _refreshFiles();
    if (!mounted || diff.newUnmatched == 0) return;
    final n = diff.newUnmatched;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$n new file${n == 1 ? '' : 's'} found since the last scan.'),
      action: _isRunning
          ? null
          : SnackBarAction(label: 'Fetch', onPressed: _scanAllSystems),
      duration: const Duration(seconds: 6),
    ));
  }


  // Re-walks folders for added/removed files, no hashing, no RA calls.
  // Never-scanned folders are skipped so a fresh library isn't one giant
  // "new files" batch.
  Future<({int added, int removed, int newUnmatched})> _refreshFiles() async {
    var added = 0;
    var removed = 0;
    var newUnmatched = 0;
    for (final dir in List<Directory>.from(_subfolders)) {
      final data = await _lib.load(dir.path);
      final consoleId = await ScanSettings.consoleIdForFolder(dir.path);
      final raSupported = ConsoleMap.isRaSupported(consoleId);
      // A never-scanned RA folder waits for a full hash scan (Update library);
      // diffing an empty one would flag every file as new-to-fetch. Non-RA /
      // unknown folders are never hashed, so bootstrap their size-only entries
      // here instead (otherwise they'd stay empty forever).
      if (data.games.isEmpty && raSupported) continue;
      final files = await listRomFiles([dir.path], _enabledExtensions);
      final byPath = {for (final g in data.games) g.filePath: g};
      final currentPaths = {for (final f in files) f.path};

      final removedHere =
          data.games.where((g) => !currentPaths.contains(g.filePath)).length;
      final games = <GameEntry>[];
      var addedHere = 0;
      for (final f in files) {
        final existing = byPath[f.path];
        if (existing != null) {
          games.add(existing);
          continue;
        }
        addedHere++;
        games.add(GameEntry.unscanned(f.path, fileSize: f.size));
      }
      if (addedHere == 0 && removedHere == 0) continue;
      added += addedHere;
      removed += removedHere;
      // Only RA-supported folders have anything to fetch; don't prompt for the rest.
      if (raSupported) newUnmatched += addedHere;

      await _lib.save(data.copyWith(games: games, consoleId: consoleId));
    }
    if (added > 0 || removed > 0) await _loadFolderStats();
    return (added: added, removed: removed, newUnmatched: newUnmatched);
  }

  Future<void> _loadHomeSortPref() async {
    final prefs = await SharedPreferences.getInstance();
    final v = HomeSort.values.asNameMap()[prefs.getString(PrefKeys.homeSort)];
    if (v != null && mounted) setState(() => _homeSort = v);
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(PrefKeys.raUsername) ?? '';
    // FetchFab reads the cached picture straight from prefs; refresh it here in
    // the background so the next read is current.
    if (name.isNotEmpty) _refreshAvatar();
  }

  // Resolve the avatar from RA's authoritative UserPic path; the media host is
  // case-sensitive, so a URL built from the typed username can serve a stale
  // legacy image. The path is stable, so a version param busts a changed avatar.
  // A failed fetch keeps the last-known picture.
  Future<void> _refreshAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(PrefKeys.raUsername) ?? '';
    final apiKey = await readApiKey();
    if (username.isEmpty || apiKey.isEmpty) return;
    try {
      final path =
          await RaService(username: username, apiKey: apiKey).getUserPicPath();
      final version = DateTime.now().millisecondsSinceEpoch;
      await raCacheManager.downloadFile(raAvatarUrl(path, version: version));
      await prefs.setString(PrefKeys.raAvatarPath, path);
      await prefs.setInt(PrefKeys.raAvatarVersion, version);
      // Tell any mounted FetchFab to re-read; it cached the old prefs when it
      // mounted, which on a first launch is before this resolves.
      raAvatarListenable.value++;
    } catch (_) {
      // Keep the previously cached avatar.
    }
  }

  // Re-derives Played from progress, and re-reads which member keys the library
  // can still show so the playlist cards stop counting deleted games. Both come
  // off the same index a playlist view lists from, so a card's count and its
  // contents can't disagree.
  Future<void> _refreshPlaylists() async {
    final rows = await _lib.searchIndex();
    final live = <String>{};
    final played = <String>{};
    for (final r in rows) {
      final key = memberKeyFor(gameId: r.gameId, filePath: r.filePath);
      live.add(key);
      if ((r.earnedAchievements ?? 0) > 0) played.add(key);
    }
    await _playlistStore.setMembers(playedId, played);
    _playlists = await _playlistStore.all();
    if (mounted) setState(() => _liveMemberKeys = live);
  }

  Future<void> _loadFilters() async {
    final extensions = await ScanSettings.enabledExtensions();
    final ignored = await ScanSettings.ignoredFolders();
    if (!mounted) return;
    setState(() {
      _enabledExtensions = extensions;
      _ignoredFolders = ignored.map((e) => e.toLowerCase()).toSet();
    });
  }

  Future<void> _restoreLastFolder() async {
    final last = libraryFolderListenable.value;
    if (last != null && Directory(last).existsSync()) {
      setState(() => _rootPath = last);
      _loadSubfolders(last);
    }
  }

  void _loadSubfolders(String path) {
    // The root can be an unmounted drive; keep the cached cards rather than
    // throwing out of whichever listener triggered this.
    if (!Directory(path).existsSync()) return;
    final subs = Directory(path)
        .listSync()
        .whereType<Directory>()
        .where((d) => !ScanSettings.isFolderIgnored(d.path, _ignoredFolders))
        .toList();
    setState(() {
      _subfolders = subs;
      _stats.clear();
      _folderConsoleIds.clear();
    });
    _loadFolderConsoleIds();
    _loadFolderStats();
  }

  // Re-reads the root for added/removed subfolders AND re-walks file lists,
  // then reports the combined diff.
  /// [quiet] skips the summary snackbar, for when this is the first phase of a
  /// larger run rather than something the user asked for on its own.
  Future<void> _refreshFolders({bool quiet = false}) async {
    final root = _rootPath;
    if (root == null) return;
    if (!Directory(root).existsSync()) {
      setState(() {
        _rootPath = null;
        _subfolders = [];
        _stats.clear();
        _folderConsoleIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder no longer exists. Pick a new one.')),
        );
      }
      return;
    }
    final before = _subfolders.map((d) => d.path).toSet();
    _loadSubfolders(root);
    final after = _subfolders.map((d) => d.path).toSet();
    final foldersAdded = after.difference(before).length;
    final foldersRemoved = before.difference(after).length;

    await _lib.refreshMissingSystems();
    final diff = await _refreshFiles();
    if (!mounted || quiet) return;

    final parts = <String>[];
    if (foldersAdded > 0 || foldersRemoved > 0) {
      parts.add('folders +$foldersAdded / −$foldersRemoved');
    }
    parts.add('files +${diff.added} / −${diff.removed}');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Refreshed: ${parts.join('  ·  ')}'),
      action: diff.newUnmatched > 0 && !_isRunning
          ? SnackBarAction(label: 'Fetch', onPressed: _scanAllSystems)
          : null,
      duration: const Duration(seconds: 5),
    ));
  }

  // Resolves console ids for the grid pictures. Best-effort, cosmetic.
  Future<void> _loadFolderConsoleIds() async {
    final dirs = List<Directory>.from(_subfolders);
    for (final dir in dirs) {
      final id = await ScanSettings.consoleIdForFolder(dir.path);
      if (!mounted) return;
      setState(() => _folderConsoleIds[dir.path] = id);
    }
  }

  // Summaries come from the home index; no disk walk here.
  Future<void> _loadFolderStats() async {
    final summaries = await _lib.summaries();
    if (!mounted) return;
    setState(() {
      for (final s in summaries) {
        _stats[s.systemPath] = FolderStats(
          path: s.systemPath,
          totalGames: s.totalGames,
          totalSizeBytes: s.totalSizeBytes,
          gamesScanned: s.gamesScanned,
          gamesWithAchievements: s.gamesWithAchievements,
          lastScanned: s.lastScanned,
        );
        if (s.consoleId != null) _folderConsoleIds[s.systemPath] = s.consoleId;
      }
    });
  }

  Future<void> _pickFolder() => pickLibraryFolder(context);

  // Pushes a folder view and refreshes stats + the playlists on return.
  void _openFolderView(FolderView view) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => view)).then((_) {
      if (_rootPath != null) _loadFolderStats();
      _refreshPlaylists();
    });
  }

  void _openSubfolder(String dirPath) => _openFolderView(FolderView(
        folderPaths: [dirPath],
        title: displayNameFor(
          mode: _nameMode,
          consoleId: _folderConsoleIds[dirPath],
          folderPaths: [dirPath],
        ),
        enabledExtensions: _enabledExtensions,
      ));

  void _openCombined(ConsoleGroup group, String label) =>
      _openFolderView(FolderView(
        folderPaths: group.folderPaths,
        title: label,
        consoleId: group.consoleId,
        enabledExtensions: _enabledExtensions,
      ));

  // [paths] is one folder, or every folder of a combined console group. The
  // ignore action only makes sense for a single folder.
  Future<void> _showFolderMenu(Offset position, List<String> paths) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final name = p.basename(paths.first);
    final favorite = FavoriteSystems.isFavorite(_favorites, paths);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(favorite ? Icons.favorite : Icons.favorite_border,
                  size: 18, color: kFavoriteColor),
              const SizedBox(width: 8),
              Flexible(
                  child:
                      Text(favorite ? 'Remove from favorites' : 'Favorite')),
            ],
          ),
        ),
        if (paths.length == 1)
          PopupMenuItem(
            value: 'ignore',
            child: Row(
              children: [
                const Icon(Icons.visibility_off, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text('Ignore "$name"')),
              ],
            ),
          ),
      ],
    );
    if (choice == 'ignore') await _ignoreFolder(name);
    if (choice == 'favorite') await _toggleFavorite(paths, favorite);
  }

  // A combined group follows its first folder, so the whole group flips
  // together rather than splitting across the two sections.
  Future<void> _toggleFavorite(List<String> paths, bool favorite) async {
    var updated = _favorites;
    for (final path in paths) {
      final isFavorite = FavoriteSystems.isFavorite(updated, [path]);
      if (isFavorite != favorite) continue; // already on the target side
      updated = await FavoriteSystems.toggle(path);
    }
    if (mounted) setState(() => _favorites = updated);
  }

  // The cards refresh through the scanFiltersListenable listener.
  Future<void> _ignoreFolder(String name) async {
    await ScanSettings.addIgnoredFolder(name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ignoring "$name". Manage the list in Settings.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _unignoreFolder(name),
          ),
        ),
      );
    }
  }

  Future<void> _unignoreFolder(String name) async {
    final remaining = (await ScanSettings.ignoredFolders())
        .where((e) => e.toLowerCase() != name.toLowerCase())
        .toList();
    await ScanSettings.setIgnoredFolders(remaining.join(', '));
  }

  // Sweeps every subfolder in turn, updating each folder card live.
  // [plan] pre-builds the run and skips the task dialog, used by the setup
  // wizard's first scan. Interactive callers pass nothing and get the dialog.
  Future<void> _scanAllSystems({FetchPlan? plan}) async {
    // A stale snackbar action (its onPressed was built before the run started)
    // or the folder view's FAB could otherwise start a second run over the same
    // folders; both would write the same SystemData and one would lose.
    if (ScanRun.busy) return;
    plan ??= await showFetchTasksDialog(context, global: true);
    if (plan == null || !mounted) return;

    // Phase one, local and free: re-walk the disk so folders and files added
    // since the last run are part of this one. Quiet, because the scan that
    // follows has its own bar and its own summary; two snackbars in a row for
    // one press is noise.
    if (plan.refresh) {
      await _refreshFolders(quiet: true);
      if (!mounted) return;
    }

    final dirs = List<Directory>.from(_subfolders);
    if (dirs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subfolders to scan.')),
      );
      return;
    }

    // Credentials only needed when we hit the network.
    (String, String)? credentials;
    if (plan.match || plan.progress || plan.refreshLists) {
      credentials = await requireCredentials(context);
      if (credentials == null) return;
    }

    // Re-pull game/hash lists first so a match step in this run sees them.
    if (plan.refreshLists && credentials != null) {
      await _refreshRaLists(credentials);
      if (!plan.match && !plan.progress) {
        _notify('RA lists refreshed');
        return;
      }
    }

    final summaries = await _lib.summaries();
    // Any folder still holding an unresolved game, not just an untouched one:
    // a cancelled sweep leaves a folder part-scanned, and "only unfetched" has
    // to be able to pick it back up.
    final unfetched = {
      for (final s in summaries)
        if (s.gamesScanned < s.totalGames) s.systemPath
    };
    // Stored games are only needed for the `changed` scope.
    // Loads every system file + re-walks every folder serially to
    // build the diff; fine at current library sizes, parallelize if it drags.
    final changedScanCache = <String, List<GameEntry>>{};
    final currentSizesCache = <String, Map<String, int>>{};
    if (plan.scope == FetchScope.changedFolders) {
      for (final s in summaries) {
        changedScanCache[s.systemPath] =
            (await _lib.load(s.systemPath)).games;
        currentSizesCache[s.systemPath] = await _currentSizesFor(s.systemPath);
      }
    }
    final freshness = plan.scope == FetchScope.changedFolders
        ? classifyFolders(
            systemPaths: summaries.map((s) => s.systemPath).toList(),
            storedGames: (path) => changedScanCache[path] ?? const <GameEntry>[],
            folderExists: (path) => Directory(path).existsSync(),
            currentSizes: (path) => currentSizesCache[path] ?? const {},
          )
        : const FolderFreshness(gone: [], changed: []);
    final targetPaths = resolveScopeFolders(
      scope: plan.scope,
      allFolders: dirs.map((d) => d.path).toList(),
      changedFolders: freshness.changed,
      unfetchedFolders: unfetched,
    ).toSet();
    final targets = dirs.where((d) => targetPaths.contains(d.path)).toList();
    if (targets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No folders match that scope.')),
      );
      return;
    }

    LogService.info('HomeScreen/scanAllSystems',
        'Starting sweep of ${targets.length} subfolders');

    final service = credentials == null
        ? null
        : RaService(username: credentials.$1, apiKey: credentials.$2);

    final onlyUnfetched = !plan.matchReFetchAll;

    final run = ScanRun();
    setState(() {
      _run = run;
      _isRunning = true;
      _checked = 0;
      _folderCount = targets.length;
      _folderIndex = 0;
      _scanAllTotal = 0;
    });
    // Counting walks every folder, which on a big library takes long enough
    // that starting it without a bar reads as a hung app. Show an
    // indeterminate one with Cancel live, then fill the total in.
    run.start(label: _scanAllLabel());

    // The bar lives above the Navigator, so every exit from here has to stop
    // it: an early return or a throw would otherwise leave it up for the rest
    // of the session, with a Cancel button wired to a dead sweep.
    try {
      final total = await _sweepTotal(targets, plan, onlyUnfetched);
      if (!mounted) return;
      setState(() => _scanAllTotal = total);
      run.addTotal(total);
      _setUpdates.clear();

      // Sweep-wide caches: one game list per console, one detail per game.
      final raCache = RaCache();
      final detailCache = <int, (GameInfo, UserProgress)>{};
      final metadataProvider = await savedMetadataProvider();

      // One completion sweep for the whole run: ceil(playedGames/500) requests
      // no matter how many folders or ROMs follow, shared with every folder
      // below. A failed sweep leaves this null, and the runner then writes no
      // progress at all rather than zeroing what is already stored. Inside the
      // bar, because on a big account it is the slowest thing before hashing.
      Map<int, CompletedGame>? progressByGameId;
      if (plan.progress && service != null) {
        final sweep = await fetchCompletionSweep(service, 'HomeScreen/scan');
        progressByGameId = sweep.byGameId;
        if (!mounted) return;
        if (sweep.userMessage != null) _notify(sweep.userMessage!);
      }

      for (final dir in targets) {
        if (!mounted || run.cancelled) break;
        setState(() {
          _folderIndex++;
          _currentFolder = p.basename(dir.path);
        });
        run.relabel(_scanAllLabel());

        final result = await runFolderFetch(
          folderPath: dir.path,
          plan: plan,
          extensions: _enabledExtensions,
          library: _lib,
          run: run,
          raCache: raCache,
          detailCache: detailCache,
          service: service,
          metadataProvider: metadataProvider,
          progressByGameId: progressByGameId,
          logContext: 'HomeScreen/scan',
          onEntry: (_) {
            if (!mounted) return;
            setState(() => _checked++);
            run.relabel(_scanAllLabel());
          },
        );
        _setUpdates.addAll(result.setUpdates);
        if (mounted) {
          setState(() => _stats[dir.path] = _statsFrom(result));
        }
      }
    } finally {
      run.stop();
      // Cleared here, not after the block: a throw out of the sweep would
      // otherwise leave _isRunning latched for the session, and every folder
      // card stays untappable with no bar on screen to explain why.
      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentFolder = null;
        });
      }
    }

    if (mounted) {
      if (_setUpdates.isNotEmpty) {
        final n = _setUpdates.length;
        final sample = _setUpdates.take(3).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$n game${n == 1 ? '' : 's'} gained new achievements on RA: '
              '$sample${n > 3 ? '…' : ''}'),
          duration: const Duration(seconds: 6),
        ));
      }
    }
    // The sweep resynced progress and rebuilt each system's file list. The
    // library listener stays out of its way while it runs, so the cards and
    // Played are refreshed once here instead.
    if (mounted) {
      await _loadFolderStats();
      await _refreshPlaylists();
    }

    LogService.info('HomeScreen/scanAllSystems',
        'Sweep finished: $_checked ROMs checked'
        '${(_run?.cancelled ?? false) ? ' (cancelled)' : ''}');

    // Offer to import Skraper data sitting alongside the ROMs.
    final rootPath = _rootPath;
    if (rootPath != null && !(_run?.cancelled ?? false) && mounted) {
      await _offerScrapedImport(rootPath);
    }
  }

  // Prompts to import gamelist.xml data found under [rootPath] after a scan, so
  // scraped artwork/details fill RA gaps for the games just scanned.
  Future<void> _offerScrapedImport(String rootPath) async {
    try {
      // Detect off the UI isolate so a deep tree doesn't jank the frame.
      final found =
          await Isolate.run(() => findScrapeSources(Directory(rootPath)).length);
      if (found == 0 || !mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scraped data found'),
          content: Text('Found gamelist.xml for $found '
              'folder(s). Import artwork & details to fill gaps?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Import')),
          ],
        ),
      );
      if (ok != true) return;
      final scanned = await Library.instance.allRomPaths();
      final result = await importFromDirectory(rootPath, scanned);
      await ScrapedStore.instance.putAll(result.matched);
    } catch (e) {
      LogService.error(
          'HomeScreen/offerScrapedImport', 'import failed', err: e);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // Re-pulls each console's game+hash list so new games match without a rescan.
  Future<void> _refreshRaLists((String, String) creds) async {
    final (username, apiKey) = creds;
    final service = RaService(username: username, apiKey: apiKey);
    final cache = RaCache();
    final summaries = await _lib.summaries();
    final consoleIds = <int>{
      for (final s in summaries)
        if (s.consoleId != null) s.consoleId!,
    };
    for (final consoleId in consoleIds) {
      try {
        await cache.refreshConsole(consoleId, service);
      } catch (e) {
        LogService.error('home/refreshLists', 'console $consoleId: $e');
      }
    }
    _refreshAvatar(); // cheap standalone fetch; not part of the re-pull
  }

  Widget _buildSyncControls() => FetchFab(onPressed: _scanAllSystems);

  // How many items this sweep will actually tick off, so the progress bar's
  // denominator matches its numerator. Counting the *files about to be
  // processed* rather than the games a previous scan happened to record: on a
  // first run nothing is recorded yet, which used to leave the bar reading
  // things like "1400/53" and pinned at 100% from item 54 onward.
  //
  // Costs one directory walk per folder up front. That is cheap beside hashing,
  // which reads every ROM end to end.
  Future<int> _sweepTotal(
      List<Directory> targets, FetchPlan plan, bool onlyUnfetched) async {
    var total = 0;
    for (final dir in targets) {
      if (!mounted || (_run?.cancelled ?? false)) break;
      if (plan.match) {
        final files = await listRomFiles([dir.path], _enabledExtensions);
        if (!onlyUnfetched) {
          total += files.length;
          continue;
        }
        // Same filter the folder scan applies, so the two agree.
        final consoleId = await ScanSettings.consoleIdForFolder(dir.path);
        final stored = {
          for (final g in (await _lib.load(dir.path)).games) g.filePath: g
        };
        total += files
            .where((f) => !isResolvedEntry(stored[f.path], consoleId))
            .length;
      } else if (plan.progress) {
        // The progress-only pass ticks once per game that has an RA id.
        final stored = (await _lib.load(dir.path)).games;
        total += stored.where((g) => g.gameId != null).length;
      }
    }
    return total;
  }

  // Phone held sideways: show the shortcuts as chips (like portrait) and a
  // tighter system grid, rather than the desktop's big leading cards.
  bool _isLandscapePhone() => context.isLandscapePhone;

  @override
  Widget build(BuildContext context) {
    final grid = _combineSystems ? _buildCombinedGrid() : _buildSubfolderGrid();
    return Scaffold(
      body: Column(
        children: [
          // Picker header shows only until a folder is chosen.
          if (_rootPath == null) _buildHeader(),
          Expanded(
            child: _rootPath == null
                ? grid
                : HomeSearch(
                    store: _playlistStore,
                    onPlaylistChanged: _refreshPlaylists,
                    idleActions: _idleActions(),
                    idleTrailing: [_buildSortButton()],
                    onOpenFolder: _openSubfolder,
                    child: grid,
                  ),
          ),
        ],
      ),
      // The scan/sync button is always available on the Library tab, including
      // before a folder is picked and in Play mode.
      floatingActionButton: _buildSyncControls(),
    );
  }

  // Shown beside the search bar when no query is active.
  List<Widget> _idleActions() {
    final style = IconButton.styleFrom(
      minimumSize: const Size(40, 40),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final narrow = MediaQuery.sizeOf(context).width < kBreakCompact;
    final landscape = _isLandscapePhone();
    return [
      // On phones (portrait or landscape) the shortcuts live here as buttons
      // instead of eating the grid, so the systems stay in reach.
      if (narrow || landscape) ..._shortcutChips(),
      // Scan health is a desktop-sized report; phones don't get the button.
      if (!narrow && !landscape && !gamingMode)
        IconButton(
          style: style,
          icon: const Icon(Icons.health_and_safety_outlined),
          // Deliberately stays enabled during a scan; it's read-only.
          tooltip: 'Scan health & export',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanHealthScreen()),
          ),
        ),
    ];
  }

  List<Widget> _shortcutChips() => [
        if (_subfolders.isNotEmpty)
          _shortcutButton(Icons.apps, 'All games',
              _isRunning ? null : _openAllGames),
        for (final pl in _playlists)
          _shortcutButton(_playlistIcon(pl), pl.name, () => _openPlaylist(pl)),
      ];

  Widget _shortcutButton(IconData icon, String label, VoidCallback? onTap) =>
      IconButton(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon),
        tooltip: label,
        onPressed: onTap,
      );

  Widget _buildSortButton() {
    return PopupMenuButton<HomeSort>(
      tooltip: 'Sort folders',
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sort, size: 18),
          const SizedBox(width: 4),
          Text(homeSortLabel(_homeSort), style: const TextStyle(fontSize: 13)),
        ]),
      ),
      onSelected: (v) async {
        setState(() => _homeSort = v);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PrefKeys.homeSort, v.name);
      },
      itemBuilder: (_) => [
        for (final sort in HomeSort.values)
          PopupMenuItem<HomeSort>(
            value: sort,
            child: Row(children: [
              if (_homeSort == sort) ...[
                const Icon(Icons.check, size: 16),
                const SizedBox(width: 6),
              ] else
                const SizedBox(width: 22),
              Text(homeSortLabel(sort)),
            ]),
          ),
      ],
    );
  }

  // Only rendered while no library folder is picked (so no scan can run).
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: const Icon(Icons.folder_open),
          label: const Text('Pick folder'),
          onPressed: _pickFolder,
        ),
      ),
    );
  }

  bool get _isNarrow => MediaQuery.sizeOf(context).width < kBreakCompact;

  // Shared shell: three headed blocks, in order — the built-in shortcuts (All
  // games + playlists), the favorited systems, then the rest. Phones get a
  // one-column list of rows per block, anything wider the flip-card grid.
  Widget _tiles({
    required List<Widget> favorites,
    required List<Widget> systems,
    required List<Widget> unsupported,
  }) {
    final narrow = _isNarrow;
    final landscape = _isLandscapePhone();
    // Phones (portrait or landscape) show the shortcuts as chips under the
    // search bar instead of as leading cards.
    final shortcuts = <Widget>[
      if (!narrow && !landscape) ...[
        if (_subfolders.isNotEmpty) _buildAllGamesCard(narrow),
        for (final pl in _playlists) _buildPlaylistCard(pl, narrow),
      ],
    ];
    final blocks = <({String title, List<Widget> tiles})>[
      if (shortcuts.isNotEmpty) (title: 'Shortcuts', tiles: shortcuts),
      if (favorites.isNotEmpty) (title: 'Favorites', tiles: favorites),
      if (systems.isNotEmpty) (title: 'Systems', tiles: systems),
      // Systems RA can't validate (Switch, PS3…, or an unidentified folder)
      // sit in their own block instead of wearing a badge each.
      if (unsupported.isNotEmpty)
        (title: 'No RetroAchievements', tiles: unsupported),
    ];
    return CustomScrollView(
      slivers: [
        for (final block in blocks) ...[
          _sectionHeader(block.title),
          if (narrow)
            _rowBlock(block.tiles)
          // The shortcuts aren't systems, so they get short wide tiles rather
          // than the console cards' picture-sized squares.
          else if (block.title == 'Shortcuts')
            _gridBlock(block.tiles, extent: 200, aspectRatio: 3.2, spacing: 8)
          else
            _gridBlock(block.tiles,
                extent: landscape ? 200 : 260, aspectRatio: 1.3),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _sectionHeader(String title) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: context.ui.muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Divider(
                  height: 1, color: context.ui.muted.withValues(alpha: 0.3)),
            ),
          ]),
        ),
      );

  // Default (hardEdge) clip: a popped card still overlaps its neighbours, but
  // clips at the viewport edge instead of painting over the search bar above
  // it. Landscape phone gets a tighter grid so systems read slightly smaller.
  Widget _gridBlock(
    List<Widget> tiles, {
    required double extent,
    required double aspectRatio,
    double spacing = 12,
  }) =>
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: extent,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          delegate: SliverChildListDelegate(tiles),
        ),
      );

  Widget _rowBlock(List<Widget> tiles) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            for (final tile in tiles)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8), child: tile),
          ]),
        ),
      );

  // One home shortcut (All games, a playlist), in whichever shape the shell is
  // laying out.
  Widget _shortcut({
    required IconData icon,
    required String label,
    String? sub,
    required VoidCallback? onTap,
    required bool narrow,
  }) {
    if (!narrow) {
      return ConsoleCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        focusScale: 1.05,
        showRing: false,
        // Built under ConsoleCard's light theme so the labels come out dark.
        child: Builder(
          builder: (context) => Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (sub != null)
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ConsoleCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      // Built under ConsoleCard's light theme so the labels come out dark.
      child: Builder(
        builder: (context) => Row(
          children: [
            SizedBox(width: 76, child: Icon(icon, size: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub != null)
                    Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Every game across every system, in the shared folder view: classic
  // filters, no per-system fetch actions (mixed consoles).
  void _openAllGames() => _openFolderView(FolderView(
        folderPaths: _subfolders.map((d) => d.path).toList(),
        title: 'All games',
        enabledExtensions: _enabledExtensions,
        showActions: false,
      ));

  Widget _buildAllGamesCard(bool narrow) => _shortcut(
        icon: Icons.apps,
        label: 'All games',
        onTap: _isRunning ? null : _openAllGames,
        narrow: narrow,
      );

  Widget _buildSubfolderGrid() {
    if (_rootPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: context.ui.muted),
            const SizedBox(height: 16),
            const Text('Pick a folder to browse subfolders.'),
          ],
        ),
      );
    }

    final narrow = _isNarrow;
    final favorites = <Widget>[];
    final rest = <Widget>[];
    final unsupported = <Widget>[];
    for (final dir in _sortedSubfolders) {
      final displayName = displayNameFor(
        mode: _nameMode,
        consoleId: _folderConsoleIds[dir.path],
        folderPaths: [dir.path],
      );
      final favorite = FavoriteSystems.isFavorite(_favorites, [dir.path]);
      final tile = _systemTile(
        paths: [dir.path],
        name: p.basename(dir.path),
        displayName: displayName,
        stats: _stats[dir.path],
        consoleId: _folderConsoleIds[dir.path],
        favorite: favorite,
        narrow: narrow,
        onTap: _isRunning ? null : () => _openSubfolder(dir.path),
      );
      _bucketFor(
        favorite: favorite,
        consoleId: _folderConsoleIds[dir.path],
        favorites: favorites,
        systems: rest,
        unsupported: unsupported,
      ).add(tile);
    }
    return _tiles(
        favorites: favorites, systems: rest, unsupported: unsupported);
  }

  Widget _buildCombinedGrid() {
    final narrow = _isNarrow;
    final favorites = <Widget>[];
    final rest = <Widget>[];
    final unsupported = <Widget>[];
    for (final entry in _combinedEntries) {
      final g = entry.group;
      final favorite = FavoriteSystems.isFavorite(_favorites, g.folderPaths);
      final tile = _systemTile(
        paths: g.folderPaths,
        name: displayNameFor(
          mode: NameMode.folderName,
          consoleId: g.consoleId,
          folderPaths: g.folderPaths,
        ),
        displayName: entry.label,
        stats: entry.agg,
        consoleId: g.consoleId,
        subtitle:
            g.folderPaths.length > 1 ? '${g.folderPaths.length} folders' : null,
        favorite: favorite,
        narrow: narrow,
        onTap: _isRunning ? null : () => _openCombined(g, entry.label),
      );
      _bucketFor(
        favorite: favorite,
        consoleId: g.consoleId,
        favorites: favorites,
        systems: rest,
        unsupported: unsupported,
      ).add(tile);
    }
    return _tiles(
        favorites: favorites, systems: rest, unsupported: unsupported);
  }

  // Which block a tile belongs to. A favorite stays under Favorites even when
  // RA doesn't cover it: the user pinned it deliberately.
  List<Widget> _bucketFor({
    required bool favorite,
    required int? consoleId,
    required List<Widget> favorites,
    required List<Widget> systems,
    required List<Widget> unsupported,
  }) {
    if (favorite) return favorites;
    return ConsoleMap.isRaSupported(consoleId) ? systems : unsupported;
  }

  // One system tile (a folder, or a combined console group), with the
  // right-click/long-press menu both shapes share.
  Widget _systemTile({
    required List<String> paths,
    required String name,
    required String displayName,
    required FolderStats? stats,
    required int? consoleId,
    String? subtitle,
    required bool favorite,
    required bool narrow,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      // Opaque: FolderCard's flip Transform can make deferToChild
      // hit-tests miss, swallowing right-click/long-press.
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: _isRunning
          ? null
          : (d) => _showFolderMenu(d.globalPosition, paths),
      onLongPressStart: _isRunning
          ? null
          : (d) => _showFolderMenu(d.globalPosition, paths),
      child: narrow
          ? FolderRow(
              name: name,
              displayName: displayName,
              stats: stats,
              consoleId: consoleId,
              subtitle: subtitle,
              favorite: favorite,
              onTap: onTap,
            )
          : FolderCard(
              name: name,
              displayName: displayName,
              stats: stats,
              consoleId: consoleId,
              subtitle: subtitle,
              favorite: favorite,
              onTap: onTap,
            ),
    );
  }

  Widget _buildPlaylistCard(Playlist pl, bool narrow) {
    return GestureDetector(
      onSecondaryTapDown: pl.builtin
          ? null
          : (d) => _showPlaylistMenu(d.globalPosition, pl),
      child: _shortcut(
        narrow: narrow,
        icon: _playlistIcon(pl),
        label: pl.name,
        sub: '${visibleMemberCount(pl, _liveMemberKeys)} games',
        onTap: () => _openPlaylist(pl),
      ),
    );
  }

  IconData _playlistIcon(Playlist pl) => switch (pl.id) {
        playedId => Icons.sports_esports,
        trashId => Icons.delete_outline,
        favoritesId => Icons.favorite,
        _ => Icons.playlist_play,
      };

  void _openPlaylist(Playlist pl) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaylistView(
            playlistId: pl.id,
            playlistName: pl.name,
            playlistStore: _playlistStore,
          ),
        ),
      ).then((_) => _refreshPlaylists());

  Future<void> _showPlaylistMenu(Offset position, Playlist pl) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
          position & const Size(40, 40), Offset.zero & overlay.size),
      items: [
        _menuRow('rename', Icons.edit, 'Rename'),
        _menuRow('delete', Icons.delete_outline, 'Delete'),
      ],
    );
    if (!mounted) return;
    if (choice == 'rename') {
      final controller = TextEditingController(text: pl.name);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename playlist'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Save')),
          ],
        ),
      );
      controller.dispose();
      if (name != null && name.isNotEmpty) {
        await _playlistStore.rename(pl.id, name);
      }
    } else if (choice == 'delete') {
      await _playlistStore.delete(pl.id);
    }
    _playlists = await _playlistStore.all();
    if (mounted) setState(() {});
  }

  PopupMenuItem<String> _menuRow(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );

}
