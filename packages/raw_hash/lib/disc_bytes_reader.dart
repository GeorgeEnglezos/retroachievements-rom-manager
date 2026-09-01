import 'dart:typed_data';

/// Random-access view of a *logical* (decompressed) disc image.
///
/// Compressed GC/Wii containers (CISO/WBFS/GCZ/...) implement this so rcheevos
/// can hash them without ever materialising the full `.iso`: RA's GC/Wii hash
/// only reads a header (capped at 1 MB) plus the main.dol segments, so the
/// reader decompresses just the blocks those reads land on.
abstract class DiscBytesReader {
  /// Logical size of the decompressed disc in bytes.
  int get length;

  /// Returns exactly [length] bytes starting at logical [offset], zero-filling
  /// any region that is sparse/absent or past the end of the image.
  Uint8List read(int offset, int length);

  /// Releases the underlying file handle.
  void close();
}
