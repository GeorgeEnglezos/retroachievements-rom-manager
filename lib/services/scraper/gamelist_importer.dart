import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import '../../models/scraped_game.dart';
import '../console_map.dart';
import 'dat_parser.dart';
import 'gamelist_parser.dart';
import 'rom_path_key.dart';

/// Outcome of an import: matched games plus counts for the summary UI.
class ImportResult {
  final List<ScrapedGame> matched;
  final int unmatched;
  final Map<String, int> perSystem; // console display name -> matched count
  final int errors; // gamelists skipped because they couldn't be parsed
  const ImportResult(this.matched, this.unmatched, this.perSystem,
      {this.errors = 0});

  int get systemCount => perSystem.length;
}

/// Detects scrape sources under [rootPath] and imports them, off the UI
/// isolate. Both the recursive directory walk and the parse run inside
/// [Isolate.run]. Note: nothing here may call [LogService] (no Flutter binding
/// on a background isolate), parse failures are counted, not logged.
Future<ImportResult> importFromDirectory(
        String rootPath, Set<String> scannedRomPaths) =>
    Isolate.run(() => importFrom(findScrapeSources(Directory(rootPath)),
        scannedRomPaths: scannedRomPaths));

/// Every scrape source under [root] (recursive): EmulationStation `gamelist.xml`
/// files and Logiqx `.dat` files (Skraper's two recipes). Directories that
/// can't be read (e.g. permission denied) are skipped rather than aborting the
/// walk. Runs inside [Isolate.run] via [importFromDirectory], so it must not
/// call [LogService].
List<File> findScrapeSources(Directory root) {
  final out = <File>[];
  if (!root.existsSync()) return out;
  final stack = <Directory>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      continue; // unreadable dir, skip (can't log from a background isolate)
    }
    for (final e in entries) {
      if (e is Directory) {
        stack.add(e);
      } else if (e is File && _isScrapeSource(e.path)) {
        out.add(e);
      }
    }
  }
  return out;
}

bool _isScrapeSource(String path) {
  final name = p.basename(path).toLowerCase();
  return name == 'gamelist.xml' || p.extension(name) == '.dat';
}

/// Parses one scrape source by kind (gamelist.xml vs Logiqx .dat). A `.dat`
/// that isn't a datafile yields `[]` (see [parseDat]).
List<ScrapedGame> parseScrapeSource(File f) {
  if (p.basename(f.path).toLowerCase() == 'gamelist.xml') {
    return parseGamelist(f);
  }
  return parseDat(f);
}

/// Parses each source and keeps only games whose resolved ROM path matches a
/// scanned ROM (exact, case-insensitive). Console (for reporting only) comes
/// from each source's folder via [ConsoleMap.idForFolder]. A source that fails
/// to parse is skipped (counted in [ImportResult.errors]) so one corrupt file
/// can't abort the batch. Runs on a background isolate, must not call
/// [LogService].
ImportResult importFrom(
  List<File> sources, {
  required Set<String> scannedRomPaths,
}) {
  final index = {for (final s in scannedRomPaths) romPathKey(s)};
  final matched = <ScrapedGame>[];
  var unmatched = 0;
  var errors = 0;
  final perSystem = <String, int>{};

  for (final gl in sources) {
    final system =
        ConsoleMap.nameFor(ConsoleMap.idForFolder(gl.parent.path)) ?? 'Unknown';
    final List<ScrapedGame> games;
    try {
      games = parseScrapeSource(gl);
    } catch (_) {
      errors++;
      continue; // can't log from a background isolate; counted instead
    }
    for (final game in games) {
      if (index.contains(romPathKey(game.romPath))) {
        matched.add(game);
        perSystem[system] = (perSystem[system] ?? 0) + 1;
      } else {
        unmatched++;
      }
    }
  }
  return ImportResult(matched, unmatched, perSystem, errors: errors);
}
