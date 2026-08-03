import 'dart:io';
import 'package:rarm/services/scan_settings.dart';

/// A ROM file plus its size, gathered off the UI thread.
class RomFile {
  final String path;
  final int size;
  RomFile(this.path, this.size);
}

/// Walks [folders] recursively using the async [Directory.list] (which yields
/// to the event loop instead of blocking the UI like `listSync`) and returns
/// every file whose extension is enabled, paired with its byte size.
Future<List<RomFile>> listRomFiles(
    List<String> folders, Set<String> enabledExtensions) async {
  final excluded =
      (await ScanSettings.excludedFiles()).map((e) => e.toLowerCase()).toSet();
  final ignored =
      (await ScanSettings.ignoredFolders()).map((e) => e.toLowerCase()).toSet();
  final result = <RomFile>[];
  for (final folder in folders) {
    final dir = Directory(folder);
    if (!await dir.exists()) continue;
    // The folder can also go away mid-walk (a removable drive unmounts, the
    // user moves it), which errors the stream rather than any one file. Keep
    // what was collected and move to the next folder: a scan that throws would
    // lose every folder after this one too.
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        if (!ScanSettings.hasEnabledExtension(entity.path, enabledExtensions)) {
          continue;
        }
        if (ScanSettings.isFileExcluded(entity.path, excluded)) continue;
        if (ScanSettings.isUnderIgnoredFolder(entity.path, folder, ignored)) {
          continue;
        }
        try {
          result.add(RomFile(entity.path, await entity.length()));
        } catch (_) {
          // File vanished mid-walk; skip it.
        }
      }
    } on FileSystemException catch (_) {
      // Folder vanished mid-walk; keep the partial result.
    }
  }
  return result;
}
