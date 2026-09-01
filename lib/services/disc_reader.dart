import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:raw_hash/disc_bytes_reader.dart';

/// Opens a random-access reader for a compressed GC/Wii container, or null if
/// the extension isn't one we decompress on the fly. See [DiscBytesReader].
DiscBytesReader? openDiscReader(String path) {
  switch (p.extension(path).replaceFirst('.', '').toLowerCase()) {
    case 'ciso':
      return CisoReader.open(path);
    case 'gcz':
      return GczReader.open(path);
    case 'wbfs':
      return WbfsReader.open(path);
    default:
      return null;
  }
}

/// Dolphin CISO: `"CISO"` magic, u32 LE block size, a 32760-byte present/absent
/// map (one byte per block), then the present blocks stored back-to-back.
/// Absent blocks read back as zeros.
class CisoReader implements DiscBytesReader {
  static const _headerSize = 0x8000;
  static const _maxBlocks = _headerSize - 8; // 32760

  final RandomAccessFile _raf;
  final int _blockSize;
  final Int32List _storedIndex; // stored slot per block, -1 when absent
  final int _blockCount; // logical blocks = highest present block + 1

  CisoReader._(this._raf, this._blockSize, this._storedIndex, this._blockCount);

  static CisoReader? open(String path) {
    final raf = File(path).openSync();
    try {
      final header = raf.readSync(_headerSize);
      if (header.length < _headerSize ||
          header[0] != 0x43 || // C
          header[1] != 0x49 || // I
          header[2] != 0x53 || // S
          header[3] != 0x4F) { // O
        raf.closeSync();
        return null;
      }
      final blockSize = ByteData.sublistView(header).getUint32(4, Endian.little);
      if (blockSize == 0) {
        raf.closeSync();
        return null;
      }
      final storedIndex = Int32List(_maxBlocks);
      var stored = 0;
      var lastPresent = -1;
      for (var i = 0; i < _maxBlocks; i++) {
        if (header[8 + i] == 1) {
          storedIndex[i] = stored++;
          lastPresent = i;
        } else {
          storedIndex[i] = -1;
        }
      }
      return CisoReader._(raf, blockSize, storedIndex, lastPresent + 1);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      return null;
    }
  }

  // ponytail: logical length is highest present block + 1; an image ending in
  // sparse blocks would report short, but RA hashing only SEEK_SETs into the
  // header/main.dol near the start, so it never relies on the tail extent.
  @override
  int get length => _blockCount * _blockSize;

  @override
  Uint8List read(int offset, int len) {
    final out = Uint8List(len);
    var done = 0;
    while (done < len) {
      final pos = offset + done;
      final block = pos ~/ _blockSize;
      final within = pos % _blockSize;
      final take = (_blockSize - within).clamp(0, len - done);
      if (block < _blockCount && _storedIndex[block] >= 0) {
        _raf.setPositionSync(
            _headerSize + _storedIndex[block] * _blockSize + within);
        out.setAll(done, _raf.readSync(take));
      } // else: absent/beyond-end block stays zero
      done += take;
    }
    return out;
  }

  @override
  void close() => _raf.closeSync();
}

/// WBFS (single disc): `"WBFS"` magic, big-endian hd_sector_count, then the
/// `hd_sector_shift`/`wbfs_sector_shift` bytes. Disc 0's wlba table (big-endian
/// u16 per wbfs sector) sits at `hd_sector_size + 256` and maps each logical
/// wbfs sector to a file wbfs sector; a 0 entry is unallocated (reads as zeros).
class WbfsReader implements DiscBytesReader {
  static const _wiiSectorSize = 0x8000;
  static const _wiiSectorCount = 143432; // single-layer Wii disc

  final RandomAccessFile _raf;
  final int _wbfsSectorSize;
  final int _wbfsSectorShift;
  final ByteData _wlba; // big-endian u16 per logical wbfs sector
  final int _blocksPerDisc;

  WbfsReader._(this._raf, this._wbfsSectorSize, this._wbfsSectorShift,
      this._wlba, this._blocksPerDisc);

  static WbfsReader? open(String path) {
    final raf = File(path).openSync();
    try {
      final head = raf.readSync(10);
      if (head.length < 10 ||
          head[0] != 0x57 || // W
          head[1] != 0x42 || // B
          head[2] != 0x46 || // F
          head[3] != 0x53) { // S
        raf.closeSync();
        return null;
      }
      final hdSectorSize = 1 << head[8];
      final wbfsSectorShift = head[9];
      final wbfsSectorSize = 1 << wbfsSectorShift;
      if (wbfsSectorSize == 0) {
        raf.closeSync();
        return null;
      }
      final blocksPerDisc =
          (_wiiSectorCount * _wiiSectorSize + wbfsSectorSize - 1) ~/
              wbfsSectorSize;
      raf.setPositionSync(hdSectorSize + 256);
      final table = raf.readSync(blocksPerDisc * 2);
      return WbfsReader._(raf, wbfsSectorSize, wbfsSectorShift,
          ByteData.sublistView(table), blocksPerDisc);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      return null;
    }
  }

  // ponytail: table length assumes a single-layer disc; dual-layer clusters
  // past that report as absent, but RA hashing reads the header/main.dol near
  // the start, well inside the table.
  @override
  int get length => _blocksPerDisc * _wbfsSectorSize;

  @override
  Uint8List read(int offset, int len) {
    final out = Uint8List(len);
    var done = 0;
    while (done < len) {
      final pos = offset + done;
      final cluster = pos >> _wbfsSectorShift;
      final within = pos & (_wbfsSectorSize - 1);
      final take = (_wbfsSectorSize - within).clamp(0, len - done);
      if (cluster < _blocksPerDisc) {
        final wlba = _wlba.getUint16(cluster * 2, Endian.big);
        if (wlba != 0) {
          _raf.setPositionSync(_wbfsSectorSize * wlba + within);
          out.setAll(done, _raf.readSync(take));
        }
      } // else/wlba 0: unallocated cluster stays zero
      done += take;
    }
    return out;
  }

  @override
  void close() => _raf.closeSync();
}

/// Dolphin GCZ: 32-byte LE header, then a `num_blocks` u64 block-pointer table
/// (bit 63 flags an uncompressed block), a u32 adler table we skip, then the
/// block data. Each block decompresses (zlib) or copies to exactly `blockSize`.
class GczReader implements DiscBytesReader {
  static const _magic = 0xB10BC001;
  static const _rawFlag = 1 << 63;
  static const _offsetMask = 0x7FFFFFFFFFFFFFFF;

  final RandomAccessFile _raf;
  final int _blockSize;
  final int _dataSize; // logical (decompressed) length
  final Int64List _pointers; // raw entries (flag bit + offset)
  final int _compressedDataSize;
  final int _dataStart; // file offset where block data begins

  int _cachedBlock = -1;
  Uint8List? _cachedBytes;

  GczReader._(this._raf, this._blockSize, this._dataSize, this._pointers,
      this._compressedDataSize, this._dataStart);

  static GczReader? open(String path) {
    final raf = File(path).openSync();
    try {
      final header = ByteData.sublistView(raf.readSync(32));
      if (header.lengthInBytes < 32 ||
          header.getUint32(0, Endian.little) != _magic) {
        raf.closeSync();
        return null;
      }
      final compressedDataSize = header.getUint64(8, Endian.little);
      final dataSize = header.getUint64(16, Endian.little);
      final blockSize = header.getUint32(24, Endian.little);
      final numBlocks = header.getUint32(28, Endian.little);
      if (blockSize == 0) {
        raf.closeSync();
        return null;
      }

      final ptrBytes = ByteData.sublistView(raf.readSync(numBlocks * 8));
      final pointers = Int64List(numBlocks);
      for (var i = 0; i < numBlocks; i++) {
        pointers[i] = ptrBytes.getUint64(i * 8, Endian.little);
      }
      final dataStart = 32 + numBlocks * 8 + numBlocks * 4; // + adler table
      return GczReader._(
          raf, blockSize, dataSize, pointers, compressedDataSize, dataStart);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      return null;
    }
  }

  @override
  int get length => _dataSize;

  Uint8List _block(int i) {
    if (i == _cachedBlock) return _cachedBytes!;
    final start = _pointers[i] & _offsetMask;
    final end = (i + 1 < _pointers.length)
        ? _pointers[i + 1] & _offsetMask
        : _compressedDataSize;
    _raf.setPositionSync(_dataStart + start);
    final stored = _raf.readSync(end - start);
    final bytes = (_pointers[i] & _rawFlag) != 0
        ? stored
        : Uint8List.fromList(zlib.decode(stored));
    _cachedBlock = i;
    _cachedBytes = bytes;
    return bytes;
  }

  @override
  Uint8List read(int offset, int len) {
    final out = Uint8List(len);
    var done = 0;
    while (done < len) {
      final pos = offset + done;
      final block = pos ~/ _blockSize;
      final within = pos % _blockSize;
      final take = (_blockSize - within).clamp(0, len - done);
      if (block < _pointers.length) {
        final bytes = _block(block);
        final avail = (bytes.length - within).clamp(0, take);
        if (avail > 0) out.setRange(done, done + avail, bytes, within);
      } // else: beyond end stays zero
      done += take;
    }
    return out;
  }

  @override
  void close() => _raf.closeSync();
}
