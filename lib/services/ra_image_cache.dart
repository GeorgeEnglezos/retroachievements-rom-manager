import 'package:file/file.dart' hide FileSystem;
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Cache key, and the name of the folder and index file it writes under the
/// app-support dir. Named so a data wipe can find them (see data_wipe.dart).
const raImageCacheKey = 'raImageCache';

/// App-wide cache manager for every RA artwork request (thumbnails, achievement
/// icons, the profile avatar). Replaces DefaultCacheManager, which caps its
/// index at 200 objects and stores bytes in the OS temp dir — so a library of
/// thousands of covers/icons kept only the 200 most-recently-touched offline,
/// and Windows Storage Sense could wipe even those. This raises the cap and
/// roots the byte store in the persistent app-support dir (beside the index).
final raCacheManager = CacheManager(Config(
  raImageCacheKey,
  maxNrOfCacheObjects: 20000,
  stalePeriod: const Duration(days: 365),
  fileSystem: _AppSupportFileSystem(raImageCacheKey),
));

/// Mirrors flutter_cache_manager's IOFileSystem but roots the byte store in the
/// persistent app-support dir instead of the volatile OS temp dir. The dir is
/// resolved lazily so constructing the manager touches no plugin (safe in
/// tests); the first cache write is what hits path_provider.
class _AppSupportFileSystem implements FileSystem {
  _AppSupportFileSystem(this._cacheKey);

  final String _cacheKey;
  Future<Directory>? _fileDir;

  Future<Directory> _dir() => _fileDir ??= _createDir(_cacheKey);

  static Future<Directory> _createDir(String key) async {
    final base = await getApplicationSupportDirectory();
    const fs = LocalFileSystem();
    final dir = fs.directory(p.join(base.path, key));
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<File> createFile(String name) async {
    var dir = await _dir();
    if (!await dir.exists()) {
      _fileDir = null;
      dir = await _dir();
    }
    return dir.childFile(name);
  }
}
