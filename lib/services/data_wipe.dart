import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cull_store.dart';
import 'ignored_candidates.dart';
import 'library.dart';
import 'log_service.dart';
import 'playlist_store.dart';
import 'pref_keys.dart';
import 'ra_image_cache.dart';
import 'scraper/scraped_store.dart';

/// One thing the user can choose to delete. Settings and the API key are not
/// on this list: nothing here ever touches configuration.
enum ClearTarget {
  /// Every scanned system: hashes, RA matches, progress. Also the dismissed
  /// Home spotlights, which only name games from a scan.
  scans,

  /// Box art and descriptions imported from a Skraper / EmulationStation
  /// folder. Re-importable from the same folder.
  scrapedData,

  /// RetroAchievements game lists and third-party metadata. Pure cache,
  /// re-downloaded on the next fetch.
  raData,

  /// Cached cover and achievement images. Pure cache, re-downloaded on demand.
  artwork,

  /// Playlists (including Favorites, Played and Trash) and favorite systems.
  /// Implies [cullVerdicts], see [expandTargets].
  playlists,

  /// Which games the elimination game has judged.
  cullVerdicts,
}

/// Applies the one rule that isn't the user's to choose: a trash or favorite
/// verdict puts the game in the matching playlist, so keeping verdicts while
/// dropping playlists would leave games judged, out of the deck, and no longer
/// in the list the verdict filed them under. The only route back from there is
/// the deck's per-run undo, which is gone by then.
Set<ClearTarget> expandTargets(Set<ClearTarget> targets) =>
    targets.contains(ClearTarget.playlists)
        ? {...targets, ClearTarget.cullVerdicts}
        : targets;

/// Deletes chosen parts of what the app has written. Nothing outside the
/// chosen targets is touched: ROM files, logs, settings and the API key are
/// never in scope. Pass [baseDir] and [library] in tests.
class DataWipe {
  final Directory? baseDir;
  final Library? library;
  const DataWipe({this.baseDir, this.library});

  Future<Directory> _base() async =>
      baseDir ?? await getApplicationSupportDirectory();

  /// Deletes [targets] (plus whatever [expandTargets] adds), from disk, from
  /// prefs and from the in-memory stores. The memory pass matters as much as
  /// the files: each store caches its state and writes the whole cache back on
  /// the next edit, so a wipe that left memory alone would see the data
  /// reappear the first time the user changed anything.
  Future<void> clear(Set<ClearTarget> targets) async {
    final chosen = expandTargets(targets);
    if (chosen.isEmpty) return;
    final base = await _base();
    final prefs = await SharedPreferences.getInstance();

    if (chosen.contains(ClearTarget.scans)) {
      await (library ?? Library.instance).clear();
      await prefs.remove(PrefKeys.homeIgnoredSpotlights);
      IgnoredCandidates.instance.clear();
    }
    if (chosen.contains(ClearTarget.scrapedData)) {
      ScrapedStore.instance.clear();
      await _delete(base, p.join('data', 'scraped.json'));
    }
    if (chosen.contains(ClearTarget.raData)) {
      await _delete(base, p.join('data', 'ra_cache'));
      await _delete(base, p.join('data', 'metadata_cache'));
    }
    if (chosen.contains(ClearTarget.artwork)) {
      await _clearArtwork(base);
    }
    if (chosen.contains(ClearTarget.playlists)) {
      PlaylistStore().clear();
      await prefs.remove(PrefKeys.playlists);
      await prefs.remove(PrefKeys.favoriteSystems);
    }
    if (chosen.contains(ClearTarget.cullVerdicts)) {
      CullStore().clear();
      await prefs.remove(PrefKeys.cullDecided);
    }
  }

  /// Deletes the image cache's bytes and its index. The index sits next to the
  /// byte store on desktop and in the platform database folder on Android, so
  /// the manager empties it; the sweep then removes anything of its own left
  /// beside the support root.
  Future<void> _clearArtwork(Directory base) async {
    try {
      await raCacheManager.emptyCache();
    } catch (e) {
      LogService.error('DataWipe/artwork', 'Cannot empty the image cache',
          err: e);
    }
    if (!await base.exists()) return;
    await for (final entity in base.list(followLinks: false)) {
      if (!p.basename(entity.path).startsWith(raImageCacheKey)) continue;
      await _deletePath(entity);
    }
  }

  Future<void> _delete(Directory base, String relative) =>
      _deletePath(FileSystemEntity.isDirectorySync(p.join(base.path, relative))
          ? Directory(p.join(base.path, relative))
          : File(p.join(base.path, relative)));

  /// A delete that can't abort the rest of the wipe. A file held open by
  /// another process (an artwork read in flight, a virus scanner) is logged
  /// and skipped rather than leaving the other targets untouched.
  Future<void> _deletePath(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (e) {
      LogService.error('DataWipe', 'Cannot delete ${entity.path}', err: e);
    }
  }
}
