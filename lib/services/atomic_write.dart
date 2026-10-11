import 'dart:io';

/// Writes [contents] to [file] through `<path>.tmp` and a rename, so a crash
/// mid-write leaves the old file whole instead of a truncated one.
Future<void> writeAtomic(File file, String contents) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(contents, flush: true);
  await tmp.rename(file.path);
}
