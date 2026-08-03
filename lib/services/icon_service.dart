import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// RA thumbnail PNG -> persistent `.ico` (a .lnk IconLocation can't use PNG),
/// keyed by game id under app-support.
class IconService {
  IconService._();

  /// Pure PNG-bytes → ICO-bytes: decode, resize to 256px square, encode ICO.
  /// Returns null if the PNG can't be decoded. Kept separate (no IO) so the
  /// conversion logic is testable without platform channels.
  static List<int>? pngBytesToIco(List<int> pngBytes) {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(Uint8List.fromList(pngBytes));
    } catch (_) {
      // decodeImage throws (not just returns null) on malformed input.
      return null;
    }
    if (decoded == null) return null;
    // Single 256px square, plenty for a desktop icon. One size;
    // add smaller embedded sizes only if it looks rough when shrunk.
    final resized = img.copyResize(decoded, width: 256, height: 256);
    return img.encodeIco(resized);
  }

  /// Returns the written `.ico` File, or null on any failure (decode, encode,
  /// or IO). Never throws; callers fall back to the emulator exe icon.
  /// [key] names the cached file; use the RA game id for matched ROMs and a
  /// stable per-file key (e.g. a path hash) for unmatched ones.
  static Future<File?> pngToIco(File png, {required String key}) async {
    try {
      final bytes = pngBytesToIco(await png.readAsBytes());
      if (bytes == null) {
        LogService.error('IconService/pngToIco', 'Decode failed: ${png.path}');
        return null;
      }
      final dir = await getApplicationSupportDirectory();
      final iconsDir = Directory(p.join(dir.path, 'icons'));
      await iconsDir.create(recursive: true);
      final out = File(p.join(iconsDir.path, '$key.ico'));
      await out.writeAsBytes(bytes);
      return out;
    } catch (e) {
      LogService.error('IconService/pngToIco', 'Failed for ${png.path}', err: e);
      return null;
    }
  }
}
