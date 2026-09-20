import 'package:path/path.dart' as p;

import '../models/fetch_plan.dart';
import '../models/game_entry.dart';
import '../models/rom_result.dart' show gameDisplayName;
import '../models/system_data.dart';
import '../models/user_progress.dart';
import 'console_map.dart';
import 'disc_decompressor.dart';
import 'disc_formats.dart';
import 'fetch_engine.dart';
import 'fetch_pipeline.dart';
import 'game_lookup.dart';
import 'incremental_scan.dart';
import 'library.dart';
import 'log_service.dart';
import 'metadata/metadata_provider.dart';
import 'metadata_cache.dart';
import 'metadata_fetch.dart';
import 'ra_cache.dart';
import 'ra_service.dart';
import 'rom_file_lister.dart';
import 'scan_run.dart';
import 'scan_settings.dart';
import 'set_update.dart';

/// What one folder's run produced.
class FolderRunResult {
  /// The folder's freshly saved index. Callers refresh their cached copy from
  /// this instead of persisting the folder a second time themselves.
  final SystemData saved;

  /// Titles whose RA achievement set grew since the last scan.
  final List<String> setUpdates;

  /// Files skipped because they are compressed discs and no decompressor is
  /// available. UI callers mark these rows as an unsupported format.
  final List<String> unhashable;

  /// True when the run stopped early because the user cancelled.
  final bool cancelled;

  const FolderRunResult({
    required this.saved,
    this.setUpdates = const [],
    this.unhashable = const [],
    this.cancelled = false,
  });
}

/// Runs one folder's worth of [plan] against [library]: the shared body of the
/// home screen's sweep and the folder view's Actions button, so both hash,
/// match, and sync progress identically.
///
/// Persistence is owned here. Callers must not save the folder again after
/// this returns; they refresh from [FolderRunResult.saved] instead.
///
/// [hash] and [lookupGameId] default to the real hasher and RA cache lookup;
/// tests inject fakes so no file is read and no request is made.
///
/// [progressByGameId] is the account-wide completion sweep, fetched once by the
/// caller and shared across every folder in the run (see [fetchCompletionSweep]
/// and [progressFromSweep]). Passing it is what lets the match pass skip the
/// per-ROM detail call; leaving it null keeps whatever progress was stored.
Future<FolderRunResult> runFolderFetch({
  required String folderPath,
  required FetchPlan plan,
  required Set<String> extensions,
  required Library library,
  required ScanRun run,
  required RaCache raCache,
  required Map<int, (GameInfo, UserProgress)> detailCache,
  RaService? service,
  int? consoleId,
  MetadataProvider? metadataProvider,
  MetadataCache? metadataCache,
  Map<int, CompletedGame>? progressByGameId,
  String logContext = 'fetchRun',
  void Function(GameEntry entry)? onEntry,
  void Function(int count)? onTargets,
  HashFn? hash,
  LookupFn? lookupGameId,
}) async {
  final folderConsoleId =
      consoleId ?? await ScanSettings.consoleIdForFolder(folderPath);
  final files = await listRomFiles([folderPath], extensions);
  final sizeByPath = {for (final f in files) f.path: f.size};
  final existing = await library.load(folderPath);
  final entryByPath = {for (final g in existing.games) g.filePath: g};
  final setUpdates = <String>[];

  // Rebuilds from the current file list so removed files drop out, then saves.
  Future<FolderRunResult> finish({List<String> unhashable = const []}) async {
    // Size comes from the walk we just did, not from whatever a previous scan
    // stored: a ROM swapped for a bigger redump would otherwise keep reporting
    // the old size on the folder card until something re-hashed it.
    final games = [
      for (final f in files)
        entryByPath[f.path]?.copyWith(fileSize: sizeByPath[f.path]) ??
            GameEntry.unscanned(f.path, fileSize: sizeByPath[f.path]),
    ];
    final saved = await library
        .save(existing.copyWith(games: games, consoleId: folderConsoleId));
    return FolderRunResult(
      saved: saved,
      setUpdates: setUpdates,
      unhashable: unhashable,
      cancelled: run.cancelled,
    );
  }

  // Progress-only pass: no hashing. The sweep is one account-wide call the
  // caller makes once for the whole run, so a null map means it failed or was
  // never asked for. Writing zeros in that case would wipe everyone's
  // progress, so the folder is left exactly as it was.
  if (plan.progress && !plan.match) {
    if (progressByGameId == null) return finish();
    final withIds = existing.games.where((g) => g.gameId != null).toList();
    onTargets?.call(withIds.length);

    for (final g in withIds) {
      if (run.cancelled) break;
      final updated = g.copyWith(
        lastScanned: DateTime.now(),
        progress: progressFromSweep(g.gameId!, progressByGameId,
            achievements: g.progress?.achievements ?? const []),
      );
      entryByPath[g.filePath] = updated;
      onEntry?.call(updated);
      run.tick();
    }
    return finish();
  }

  if (!plan.match) return finish();

  // Display-only console: no RA hash exists. Fetch metadata by name when a
  // provider is configured, otherwise record size only.
  if (folderConsoleId == null || !ConsoleMap.isRaSupported(folderConsoleId)) {
    if (folderConsoleId != null &&
        metadataProvider != null &&
        metadataProvider.supports(folderConsoleId)) {
      // "Only unfetched" here means "has no metadata yet"; a no-match leaves
      // the entry bare, so it is retried next time.
      final targets = [
        for (final f in files)
          if (plan.matchReFetchAll || entryByPath[f.path]?.metadata == null)
            f.path,
      ];
      onTargets?.call(targets.length);

      await runMetadataFetch(
        files: targets,
        consoleId: folderConsoleId,
        provider: metadataProvider,
        cache: metadataCache ?? MetadataCache(),
        isCancelled: () => run.cancelled,
        onResult: (path, meta) {
          // GameEntry.copyWith cannot null a field out, and wiping a previous
          // match on a transient miss would be wrong anyway: skip no-matches.
          if (meta != null) {
            final prev = entryByPath[path] ??
                GameEntry.unscanned(path, fileSize: sizeByPath[path]);
            final updated =
                prev.copyWith(lastScanned: DateTime.now(), metadata: meta);
            entryByPath[path] = updated;
            onEntry?.call(updated);
          }
          run.tick();
        },
      );
      return finish();
    }

    LogService.warning(
        logContext,
        'Non-RA console for folder ${p.basename(folderPath)} '
        '(${ConsoleMap.nameFor(folderConsoleId) ?? 'unknown'}); '
        'recording size only (not hashed).');
    onTargets?.call(0);
    return finish();
  }

  // An RA console with no credentials cannot be looked up. Bail rather than run
  // the engine: FetchEngine swallows the thrown null-check per file and reports
  // each one as unhashed, which would rewrite the whole folder as unscanned.
  if (service == null && lookupGameId == null) return finish();

  final targets = plan.matchReFetchAll
      ? files.map((f) => f.path).toList()
      : files
          .where((f) => !isResolvedEntry(entryByPath[f.path], folderConsoleId))
          .map((f) => f.path)
          .toList();

  // CISO/WBFS/GCZ and GameCube RVZ hash on-device; only WIA (and Wii RVZ, which
  // we can't tell apart by extension) truly needs DolphinTool. Skip only the
  // never-hashable ones up front so they don't burn a slot, and report them.
  final dolphinToolPath =
      hash == null ? await DiscDecompressor.resolveToolPath() : null;
  final unhashable = (hash == null && dolphinToolPath == null)
      ? targets.where(DiscFormats.requiresDolphinTool).toList()
      : const <String>[];
  targets.removeWhere(unhashable.contains);
  onTargets?.call(targets.length);

  final engine = FetchEngine(
    hash: hash ??
        romHasher(
          consoleId: folderConsoleId,
          dolphinToolPath: dolphinToolPath,
          logContext: logContext,
        ),
    lookupGameId: lookupGameId ??
        (md5) => raCache.resolveGameId(service!, folderConsoleId, md5),
    isCancelled: () => run.cancelled,
    onResult: (res) async {
      final prev = entryByPath[res.filePath];
      // The rich per-game call is deliberately not made here: it costs one
      // request per matched ROM, and the cached console list already carries
      // everything a library row draws (title, icon, achievement count,
      // points). Box art, screenshots, genre and the achievement list are
      // fetched and persisted by the detail dialog, for the one game the user
      // actually opens.
      final cached = res.matched && res.gameId != null
          ? await raCache.entryForGame(res.gameId!, folderConsoleId)
          : null;
      var info = cached == null
          ? null
          : gameInfoFromCache(cached,
              consoleId: folderConsoleId, saved: prev?.gameInfo);

      // Matched through the dorequest fallback on a hash the console list
      // doesn't carry, so the cache cannot name it. Few enough per run that
      // the per-game call is still the right way to get a title.
      (GameInfo, UserProgress)? detail;
      if (info == null && res.matched && res.gameId != null && service != null) {
        detail = await tryResolveGameDetail(
          gameId: res.gameId!,
          service: service,
          cache: detailCache,
          // A re-fetch-all is the user asking for fresh data, so the saved
          // entry is not reused: reusing it would report the old achievement
          // count and no set update could ever be detected.
          saved: plan.matchReFetchAll ? null : prev,
          logContext: logContext,
        );
        info = detail?.$1;
      }

      if (isSetUpdate(
          prev?.gameInfo?.achievementCount, info?.achievementCount)) {
        setUpdates.add(gameDisplayName(info?.title, p.basename(res.filePath)));
      }
      final updated = GameEntry(
        filePath: res.filePath,
        fileName: p.basename(res.filePath),
        fileSize: sizeByPath[res.filePath],
        md5: res.md5,
        gameId: res.gameId,
        matched: res.matched,
        noMatch: res.noMatch,
        lastScanned: DateTime.now(),
        gameInfo: info,
        // Sweep first, then whatever the rare fallback call returned, then
        // what was already stored: never null out progress we already have.
        progress: res.gameId == null
            ? null
            : progressByGameId != null
                ? progressFromSweep(res.gameId!, progressByGameId,
                    achievements: prev?.progress?.achievements ?? const [])
                : detail?.$2 ?? prev?.progress,
        hashConsoleId: folderConsoleId,
      );
      entryByPath[res.filePath] = updated;
      onEntry?.call(updated);
      run.tick();
    },
  );

  LogService.info(logContext,
      'Fetching ${targets.length} ROMs in ${p.basename(folderPath)}');
  await engine.run(targets);

  return finish(unhashable: unhashable);
}
