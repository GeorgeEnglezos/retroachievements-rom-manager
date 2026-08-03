import 'package:path/path.dart' as p;
import 'log_service.dart';

class FetchResult {
  final String filePath;
  final String? md5;
  final int? gameId;
  final bool matched;
  final bool noMatch;
  FetchResult({
    required this.filePath,
    required this.md5,
    required this.gameId,
    required this.matched,
    required this.noMatch,
  });
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
          await onResult(_result(path, null, null, false, false));
          continue;
        }

        final gameId = await lookupGameId(md5);
        if (gameId == null) {
          await onResult(_result(path, md5, null, false, true));
        } else {
          await onResult(_result(path, md5, gameId, true, false));
        }
      } catch (e, st) {
        LogService.error('FetchEngine',
            'Error on ${p.basename(path)}: $e', err: st);
        await onResult(_result(path, null, null, false, false));
      }
    }
  }

  FetchResult _result(
          String path, String? md5, int? gameId, bool matched, bool noMatch) =>
      FetchResult(
        filePath: path,
        md5: md5,
        gameId: gameId,
        matched: matched,
        noMatch: noMatch,
      );
}
