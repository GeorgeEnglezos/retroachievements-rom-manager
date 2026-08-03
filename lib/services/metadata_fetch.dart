import 'package:path/path.dart' as p;
import '../models/game_metadata.dart';
import 'log_service.dart';
import 'metadata/metadata_provider.dart';
import 'metadata_cache.dart';
import 'rom_name.dart';

/// One metadata result per file: the [GameMetadata] match, or null for no match.
typedef MetadataResultFn = void Function(String filePath, GameMetadata? meta);

/// Name-lookup loop for display-only consoles, the third-party counterpart to
/// [FetchEngine]'s hash pipeline. Cleans each filename, checks the offline
/// [cache] first, then queries [provider]; caches hits. UI-free and injectable
/// so it's unit-testable. Per-file errors fall back to null (no match), never
/// aborting the sweep.
///
/// [isCancelled] is polled before every file so a user cancel lands mid-folder,
/// matching FetchEngine.
Future<void> runMetadataFetch({
  required List<String> files,
  required int consoleId,
  required MetadataProvider provider,
  required MetadataCache cache,
  required MetadataResultFn onResult,
  bool Function()? isCancelled,
}) async {
  for (final path in files) {
    if (isCancelled?.call() ?? false) return;
    final cleaned = cleanRomName(p.basename(path));
    GameMetadata? meta;
    try {
      meta = await cache.get(provider.id, consoleId, cleaned);
      if (meta == null) {
        meta = await provider.lookup(name: cleaned, consoleId: consoleId);
        if (meta != null) {
          await cache.put(provider.id, consoleId, cleaned, meta);
        }
      }
    } catch (e, st) {
      LogService.error(
          'metadataFetch', 'lookup ${p.basename(path)}: $e', err: st);
      meta = null;
    }
    onResult(path, meta);
  }
}
