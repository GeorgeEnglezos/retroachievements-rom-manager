import 'package:path/path.dart' as p;
import 'log_service.dart';

class FetchResult {
  final String filePath;
  final String? md5;
  final int? gameId;
  FetchResult({required this.filePath, this.md5, this.gameId});

  bool get matched => gameId != null;

  /// Hashed, but RA knows no game for the hash.
  bool get noMatch => md5 != null && gameId == null;
}

typedef HashFn = Future<String?> Function(String filePath);
typedef LookupFn = Future<int?> Function(String md5);

/// Hash -> lookup pipeline, one [FetchResult] per file via [onResult].
/// Owns no storage; all work injected so it's unit-testable.
class FetchEngine {
  final HashFn hash;
  final LookupFn lookupGameId;
  final Future<void> Function(FetchResult) onResult;

  /// Polled before every file so a user cancel lands mid-folder instead of
  /// after it. A folder can hold thousands of ROMs; finishing one is the same
  /// as ignoring the cancel.
  final bool Function()? isCancelled;

  FetchEngine({
    required this.hash,
    required this.lookupGameId,
    required this.onResult,
    this.isCancelled,
  });

  Future<void> run(List<String> files) async {
    for (final path in files) {
      if (isCancelled?.call() ?? false) return;
      try {
        final md5 = await hash(path);
        if (md5 == null) {
          await onResult(FetchResult(filePath: path));
          continue;
        }

        final gameId = await lookupGameId(md5);
        await onResult(FetchResult(filePath: path, md5: md5, gameId: gameId));
      } catch (e, st) {
        LogService.error('FetchEngine',
            'Error on ${p.basename(path)}: $e', err: st);
        await onResult(FetchResult(filePath: path));
      }
    }
  }
}
