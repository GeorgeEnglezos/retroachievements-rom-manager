import 'package:path/path.dart' as p;

import '../models/game_entry.dart';
import '../models/rom_result.dart';
import '../models/user_progress.dart';
import 'fetch_engine.dart';
import 'game_lookup.dart';
import 'hash_service.dart';
import 'log_service.dart';
import 'ra_cache.dart';
import 'ra_service.dart';

/// The callbacks and guards around the [FetchEngine] loop, shared by the
/// home-screen sweep and the folder view so both fetch the same way.

/// Builds the [FetchEngine] hash callback for [consoleId]: computes the hash
/// and logs failures under [logContext]. [dolphinToolPath] enables compressed
/// disc decompression when present.
HashFn romHasher({
  required int consoleId,
  required String? dolphinToolPath,
  required String logContext,
}) {
  return (path) async {
    final r = await HashService.computeHash(path, consoleId,
        dolphinToolPath: dolphinToolPath);
    if (r.note != null) {
      LogService.info(logContext, '${p.basename(path)}: ${r.note}');
    }
    if (r.unsupportedFormat) {
      LogService.warning(logContext,
          'Compressed disc format needs conversion to ISO (no DolphinTool): $path');
    } else if (r.hash == null && r.log.isNotEmpty) {
      LogService.warning(logContext,
          '${p.basename(path)}: no hash for console $consoleId'
          '\n${r.log.join('\n')}');
    }
    return r.hash;
  };
}

/// Resolves rich info + progress for a matched [gameId]: per-run [cache]
/// first, then the persisted [saved] entry (no network on rescans), then
/// [service]. Throws on network failure like the direct call did.
Future<(GameInfo, UserProgress)> resolveGameDetail({
  required int gameId,
  required RaService service,
  required Map<int, (GameInfo, UserProgress)> cache,
  GameEntry? saved,
}) async {
  return cache[gameId] ??= saved?.gameInfo != null
      ? reuseSavedGameData(saved!, gameId)
      : await service.getGameInfoAndUserProgress(gameId);
}

/// [resolveGameDetail] with the network failure swallowed: logs under
/// [logContext] and returns null so callers fall back gracefully.
Future<(GameInfo, UserProgress)?> tryResolveGameDetail({
  required int gameId,
  required RaService service,
  required Map<int, (GameInfo, UserProgress)> cache,
  GameEntry? saved,
  required String logContext,
}) async {
  try {
    return await resolveGameDetail(
        gameId: gameId, service: service, cache: cache, saved: saved);
  } catch (e) {
    LogService.error(
        logContext, 'getGameInfoAndUserProgress for game $gameId: $e');
    return null;
  }
}

/// Applies one [FetchEngine] result onto [rom]: hash bookkeeping, immediate
/// basic offline info, rich detail + progress (or a supported-with-placeholder
/// fallback when the detail fetch fails), noMatch/error statuses. UI-visible
/// mutations go through [mutate] so widget callers can wrap them in setState;
/// the hash bookkeeping fields are set unconditionally so they persist even
/// when the caller is unmounted.
Future<void> applyFetchResultToRom({
  required FetchResult res,
  required RomResult rom,
  required int consoleId,
  required RaService service,
  required RaCache raCache,
  required Map<int, (GameInfo, UserProgress)> detailCache,
  GameEntry? saved,
  required String logContext,
  required void Function(void Function()) mutate,
}) async {
  rom.md5Hash = res.md5;
  rom.hashConsoleId = consoleId;
  rom.gameId = res.gameId;
  if (res.matched && res.gameId != null && res.md5 != null) {
    // Show basic offline-cache info immediately so the row populates.
    final basic = await raCache.entryForGame(res.gameId!, consoleId);
    if (basic != null) mutate(() => applyBasicInfo(rom, basic));
    final detail = await tryResolveGameDetail(
        gameId: res.gameId!,
        service: service,
        cache: detailCache,
        saved: saved,
        logContext: logContext);
    mutate(() {
      if (detail != null) {
        final (info, progress) = detail;
        applyGameInfo(rom, info);
        rom.earnedAchievements = progress.earnedAchievements;
        rom.earnedHardcore = progress.earnedHardcore;
        rom.highestAward = progress.highestAward;
        rom.highestAwardDate = progress.highestAwardDate;
        rom.lastPlayed = progress.lastPlayed;
      } else {
        rom.status = RomStatus.supported;
        rom.gameTitle ??= 'Game #${res.gameId}';
      }
    });
  } else if (res.noMatch) {
    mutate(() => rom.status = RomStatus.unsupported);
  } else {
    mutate(() {
      rom.status = RomStatus.error;
      rom.errorMessage = 'Could not hash file for console $consoleId';
    });
  }
}

/// Outcome of the one-shot completion-progress sweep. [byGameId] is null when
/// the sweep failed or returned empty; in that case nothing must be written
/// (writing would zero all progress) and [userMessage] says why.
typedef CompletionSweep = ({
  Map<int, CompletedGame>? byGameId,
  String? userMessage,
});

/// Runs the completion-progress sweep (ceil(playedGames/500) calls total)
/// with the shared failure guards. Games absent from the result were never
/// played, so their earned counts stay zero.
Future<CompletionSweep> fetchCompletionSweep(
    RaService service, String logContext) async {
  List<CompletedGame> completed;
  try {
    completed = await service.getUserCompletionProgress();
  } catch (e) {
    LogService.error(logContext, 'completion sweep: $e');
    return (
      byGameId: null,
      userMessage: 'Progress sync failed. No changes made.',
    );
  }
  if (completed.isEmpty) {
    LogService.error(logContext,
        'completion sweep returned empty; skipping to avoid zeroing progress');
    return (
      byGameId: null,
      userMessage: 'No progress data returned. No changes made.',
    );
  }
  return (
    byGameId: {for (final g in completed) g.gameId: g},
    userMessage: null,
  );
}

/// The [UserProgress] for [gameId] read out of a completion [sweep]. A game the
/// sweep doesn't mention was never played, so it reads as zero rather than as
/// unknown. [achievements] carries the stored per-achievement list over: the
/// sweep is one call for the whole account and has no such detail, and dropping
/// it would blank an already-populated detail dialog.
UserProgress progressFromSweep(
  int gameId,
  Map<int, CompletedGame> sweep, {
  List<Achievement> achievements = const [],
}) {
  final c = sweep[gameId];
  return UserProgress(
    gameId: gameId,
    earnedAchievements: c?.numAwarded ?? 0,
    earnedHardcore: c?.numAwardedHardcore ?? 0,
    lastPlayed: c?.lastPlayed,
    highestAward: c?.highestAward ?? RaAward.none,
    highestAwardDate: c?.highestAwardDate,
    achievements: achievements,
  );
}
