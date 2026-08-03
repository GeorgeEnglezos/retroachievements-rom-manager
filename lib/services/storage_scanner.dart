import 'dart:io';
import 'scan_settings.dart';
import 'storage_treemap.dart';

/// The scan filters applied while measuring storage, so the Storage tab hides
/// exactly what the rest of the app hides: ignored folders, excluded files, and
/// files whose extension isn't enabled. Passed into the `compute` isolate, so it
/// carries only plain sendable data.
class StorageFilter {
  final Set<String> ignoredLower;
  final Set<String> excludedLower;
  final Set<String> enabledExtensions;
  const StorageFilter(
      this.ignoredLower, this.excludedLower, this.enabledExtensions);

  /// A file worth counting, found while walking [root]: enabled extension, not
  /// excluded, and not inside an ignored subfolder.
  bool allowsFile(String path, String root) =>
      ScanSettings.hasEnabledExtension(path, enabledExtensions) &&
      !ScanSettings.isFileExcluded(path, excludedLower) &&
      !ScanSettings.isUnderIgnoredFolder(path, root, ignoredLower);

  /// An immediate subfolder to skip entirely (by name).
  bool isDirIgnored(String path) =>
      ScanSettings.isFolderIgnored(path, ignoredLower);
}

/// One [TreemapItem] per immediate child of [args].$1 (subfolders weighted
/// recursively), with [args].$2 applied so ignored folders, excluded files, and
/// non-ROM files never appear. Zero-byte children (a folder left with nothing
/// after filtering) are dropped. Top-level so it can run in `compute`.
Future<List<TreemapItem>> childSizes((String, StorageFilter) args) async {
  final (dirPath, filter) = args;
  final dir = Directory(dirPath);
  if (!await dir.exists()) return const [];

  final items = <TreemapItem>[];
  try {
    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .lastOrNull ??
          entity.path;
      if (entity is File) {
        if (!filter.allowsFile(entity.path, dirPath)) continue;
        items.add(TreemapItem(name, await _fileLength(entity),
            path: entity.path));
      } else if (entity is Directory) {
        if (filter.isDirIgnored(entity.path)) continue;
        final size = await _dirSize(entity, filter);
        if (size == 0) continue;
        items.add(TreemapItem(name, size, path: entity.path));
      }
    }
  } on FileSystemException {
    // Permission or transient IO error: return whatever we gathered so far.
  }
  return items;
}

/// Filtered on-disk size (recursive) for each path in [args].$1. Top-level so it
/// can run in `compute`; used for the storage root so system totals match the
/// drill-down (ignored/excluded/non-ROM files excluded from both).
Future<Map<String, int>> systemSizes((List<String>, StorageFilter) args) async {
  final (paths, filter) = args;
  final out = <String, int>{};
  for (final path in paths) {
    out[path] = await _dirSize(Directory(path), filter);
  }
  return out;
}

/// Recursive total of every allowed file under [dir]. Files inside ignored
/// subfolders, excluded files, and non-ROM extensions are skipped; unreadable
/// entries too.
Future<int> _dirSize(Directory dir, StorageFilter filter) async {
  var total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!filter.allowsFile(entity.path, dir.path)) continue;
      total += await _fileLength(entity);
    }
  } on FileSystemException {
    // Skip subtrees we cannot read.
  }
  return total;
}

Future<int> _fileLength(File file) async {
  try {
    return await file.length();
  } on FileSystemException {
    return 0;
  }
}
