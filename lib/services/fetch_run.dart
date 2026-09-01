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

  /// Set when the run bailed with something worth telling the user, e.g. a
  /// failed completion sweep. Null on success.
  final String? message;

  const FolderRunResult({
    required this.saved,
    this.setUpdates = const [],
    this.unhashable = const [],
    this.cancelled = false,
    this.message,
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

  // Progress-only pass: no hashing, one sweep for the whole account.
  if (plan.progress && !plan.match) {
    if (service == null) return finish();
    final withIds = existing.games.where((g) => g.gameId != null).toList();

    final sweep = await fetchCompletionSweep(service, logContext);
    final byGameId = sweep.byGameId;
    // A failed or empty sweep must not be written; that would zero everyone's
    // progress. Return the untouched index and let the caller say why.
    if (byGameId == null) {
      return FolderRunResult(
        saved: existing,
        cancelled: run.cancelled,
        message: sweep.userMessage,
      );
    }
    // Counted after the guard: a failed sweep ticks nothing, and announcing the
    // total first would pin the bar at 0% of a number it never reaches.
    onTargets?.call(withIds.length);

    for (final g in withIds) {
      if (run.cancelled) break;
      final prog = byGameId[g.gameId!];
      final updated = g.copyWith(
        lastScanned: DateTime.now(),
        progress: UserProgress(
          gameId: g.gameId!,
          earnedAchievements: prog?.numAwarded ?? 0,
          earnedHardcore: prog?.numAwardedHardcore ?? 0,
          lastPlayed: prog?.lastPlayed,
          highestAward: prog?.highestAward ?? RaAward.none,
          highestAwardDate: prog?.highestAwardDate,
          achievements: g.progress?.achievements ?? const [],
        ),
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

  // Without a decompressor, compressed discs cannot be hashed at all. Skip
  // them up front so they do not burn a slot and report them to the caller.
  final dolphinToolPath =
      hash == null ? await DiscDecompressor.resolveToolPath() : null;
  final unhashable = (hash == null && dolphinToolPath == null)
      ? targets.where(DiscFormats.needsDecompression).toList()
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
      final detail = res.matched && res.gameId != null && service != null
          ? await tryResolveGameDetail(
              gameId: res.gameId!,
              service: service,
              cache: detailCache,
              // A re-fetch-all is the user asking for fresh data, so the saved
              // entry is not reused: reusing it would report the old
              // achievement count and no set update could ever be detected.
              saved: plan.matchReFetchAll ? null : prev,
              logContext: logContext,
            )
          : null;
      final info = detail?.$1;
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
        progress: detail?.$2,
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
