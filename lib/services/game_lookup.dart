import 'package:path/path.dart' as p;
import '../models/game_entry.dart';
import '../models/game_metadata.dart';
import '../models/rom_result.dart';
import '../models/user_progress.dart';
import 'console_map.dart';
import 'library.dart';
import 'ra_service.dart';
import 'rom_name.dart';

/// Maps a RetroAchievements [GameInfo] onto a [RomResult]. A null [info] means
/// the hash was looked up but unsupported. Shared by the folder view and the
/// storage drill-down so the mapping lives in exactly one place.
void applyGameInfo(RomResult rom, GameInfo? info) {
  if (info == null) {
    rom.status = RomStatus.unsupported;
    return;
  }
  rom.status = RomStatus.supported;
  rom.gameId = info.gameId;
  rom.gameTitle = info.title;
  rom.consoleName = info.consoleName;
  rom.consoleId = info.consoleId;
  rom.achievementCount = info.achievementCount;
  rom.imageIcon = info.imageIcon;
  rom.imageBoxArt = info.imageBoxArt;
  rom.imageTitle = info.imageTitle;
  rom.imageIngame = info.imageIngame;
  rom.publisher = info.publisher;
  rom.developer = info.developer;
  rom.genre = info.genre;
  rom.released = info.released;
  rom.setCreated = info.setCreated;
  rom.setUpdated = info.setUpdated;
  rom.points = info.points;
  rom.numPlayersCasual = info.numPlayersCasual;
  rom.numPlayersHardcore = info.numPlayersHardcore;
}

/// Maps third-party [meta] onto a [RomResult] for a display-only console. A
/// null [meta] means the name lookup found nothing; the row stays local-only.
/// Shared by the live fetch loop and [romFromEntry] so the mapping lives once.
void applyMetadata(RomResult rom, GameMetadata? meta) {
  if (meta == null) {
    rom.status = RomStatus.localOnly;
    return;
  }
  rom.status = RomStatus.metadataOnly;
  rom.metadata = meta;
  rom.gameTitle = meta.title;
  rom.publisher = meta.publisher;
  rom.developer = meta.developer;
  rom.genre = meta.genre;
  rom.released = meta.released;
  rom.imageUrl = meta.imageUrl;
  rom.lowConfidenceMatch = meta.matchConfidence < kLowConfidenceThreshold;
}

/// Applies the offline-cache [basic] entry onto [rom] so a row populates
/// immediately after the hash matches, before the richer network fetch. Shared
/// by the folder view's full scan and single-rom re-fetch.
void applyBasicInfo(RomResult rom, RaGameListEntry basic) {
  rom.status = RomStatus.supported;
  rom.gameId = basic.gameId;
  rom.gameTitle = basic.title;
  rom.achievementCount = basic.achievementCount;
  rom.imageIcon = basic.imageIcon;
  rom.points = basic.points;
}

/// A [GameInfo] built from the offline `GetGameList` cache entry, for scans
/// that skip the per-game detail call. It carries everything a library row
/// draws (title, icon, achievement count, points); box art, screenshots,
/// genre, developer, publisher and the achievement list stay null until the
/// detail dialog fetches them for the one game the user actually opened.
///
/// [saved] is what a previous scan stored for the same file, and the rich
/// fields it holds are carried over. Without that, re-hashing a library would
/// write the thin list entry straight over the entry and delete box art the
/// user already fetched. The list stays authoritative for what it does track:
/// title, achievement count, points, and the set's revision date.
GameInfo gameInfoFromCache(RaGameListEntry e, {int? consoleId, GameInfo? saved}) {
  final old = saved?.gameId == e.gameId ? saved : null;
  return GameInfo(
    gameId: e.gameId,
    title: e.title,
    consoleName:
        ConsoleMap.nameFor(e.consoleId ?? consoleId) ?? old?.consoleName ?? '',
    consoleId: e.consoleId ?? consoleId,
    achievementCount: e.achievementCount,
    imageIcon: e.imageIcon ?? old?.imageIcon,
    imageBoxArt: old?.imageBoxArt,
    imageTitle: old?.imageTitle,
    imageIngame: old?.imageIngame,
    publisher: old?.publisher,
    developer: old?.developer,
    genre: old?.genre,
    released: old?.released,
    setCreated: old?.setCreated,
    // GetGameList's DateModified is the set's last revision, the same thing
    // the per-game call's latest achievement DateModified approximates.
    setUpdated: e.dateModified ?? old?.setUpdated,
    points: e.points ?? old?.points,
    numPlayersCasual: old?.numPlayersCasual ?? 0,
    numPlayersHardcore: old?.numPlayersHardcore ?? 0,
  );
}

/// Metadata providers that were removed from the app but may have left
/// persisted [GameEntry.metadata] behind. Their blobs are stale (raw entity
/// ids as publishers, dead lookups) and must not gate a row out of localOnly;
/// localOnly is what lets imported Skraper data render for it.
const kRemovedMetadataProviders = {'wikidata'};

/// Rebuilds the renderable [RomResult] for a persisted [entry]: the one
/// mapping every screen shares. [consoleId] (when known) invalidates stale
/// noMatch entries hashed under a different console; [consoleName] overrides
/// the gameInfo value for screens that resolve it themselves.
RomResult romFromEntry(GameEntry entry, {int? consoleId, String? consoleName}) {
  final rom = RomResult(filePath: entry.filePath, fileName: entry.fileName)
    ..fileSize = entry.fileSize
    ..md5Hash = entry.md5
    ..hashConsoleId = entry.hashConsoleId
    ..gameId = entry.gameId
    ..consoleId = consoleId;
  if (entry.matched && entry.gameInfo != null) {
    applyGameInfo(rom, entry.gameInfo);
    if (consoleName != null) rom.consoleName = consoleName;
    rom.earnedAchievements = entry.progress?.earnedAchievements;
    rom.earnedHardcore = entry.progress?.earnedHardcore;
    rom.highestAward = entry.progress?.highestAward;
    rom.highestAwardDate = entry.progress?.highestAwardDate;
    rom.lastPlayed = entry.progress?.lastPlayed;
  } else if (entry.matched && entry.gameId != null) {
    // Hash matched but the detail fetch failed, so nothing rich was stored.
    // Still a supported game; showing it as unscanned would invite a pointless
    // re-hash of a file we already identified.
    rom.status = RomStatus.supported;
    rom.gameTitle = 'Game #${entry.gameId}';
    rom.consoleName ??= ConsoleMap.nameFor(consoleId) ?? consoleName;
  } else if (entry.metadata != null &&
      !kRemovedMetadataProviders.contains(entry.metadata!.providerId)) {
    // Display-only console enriched by a third-party provider.
    applyMetadata(rom, entry.metadata);
    rom.consoleName = ConsoleMap.nameFor(consoleId) ?? consoleName;
  } else if (!ConsoleMap.isRaSupported(consoleId)) {
    // Console isn't on RA (or the folder is unidentified), local info only.
    rom.status = RomStatus.localOnly;
    rom.consoleName = ConsoleMap.nameFor(consoleId) ?? consoleName;
  } else if (entry.noMatch &&
      (consoleId == null || entry.hashConsoleId == consoleId)) {
    rom.status = RomStatus.unsupported;
  } else {
    // A noMatch hashed under a different console id is stale; surface as
    // notFetched so a rescan re-hashes it.
    rom.status = RomStatus.notFetched;
  }
  return rom;
}

/// Reuses a persisted [saved] entry's rich game data so a rescan makes no
/// network call. Callers must guarantee `saved.gameInfo != null`. A missing
/// [saved.progress] is synthesized as zero-progress for [gameId].
(GameInfo, UserProgress) reuseSavedGameData(GameEntry saved, int gameId) => (
      saved.gameInfo!,
      saved.progress ??
          UserProgress(
              gameId: gameId, earnedAchievements: 0, earnedHardcore: 0),
    );

/// The scanned system folder holding [filePath], or null when none does.
Future<String?> _systemPathFor(String filePath, Library library) async =>
    (await library.summaries())
        .where((s) => p.isWithin(s.systemPath, filePath))
        .firstOrNull
        ?.systemPath;

/// Rebuilds a full [RomResult] for [filePath] from the per-system files.
/// Null when the file has no matched game; caller falls back.
Future<RomResult?> resolveRom(
  String filePath, {
  required Library library,
}) async {
  final systemPath = await _systemPathFor(filePath, library);
  if (systemPath == null) return null;

  final data = await library.load(systemPath);
  final entry = data.games.where((g) => g.filePath == filePath).firstOrNull;
  if (entry == null || !entry.matched || entry.gameInfo == null) return null;
  return romFromEntry(entry);
}

/// Persists freshly fetched [info] and [progress] onto the stored entry for
/// [filePath]. Scans deliberately skip the per-game detail call (one request
/// per matched ROM), so this is what makes box art, screenshots, genre and the
/// achievement list stick after the detail dialog has fetched them once for a
/// game the user actually opened. No-op when the file isn't in a scanned
/// system, or was never matched.
Future<void> saveGameDetail(
  String filePath, {
  required GameInfo info,
  required UserProgress progress,
  required Library library,
}) async {
  final systemPath = await _systemPathFor(filePath, library);
  if (systemPath == null) return;

  final data = await library.load(systemPath);
  final i = data.games.indexWhere((g) => g.filePath == filePath);
  if (i == -1 || !data.games[i].matched) return;
  final games = [...data.games];
  games[i] = games[i].copyWith(gameInfo: info, progress: progress);
  await library.save(data.copyWith(games: games));
}
