import 'dart:io';
import 'dart:typed_data';

import 'package:raw_hash/raw_hash.dart';

import 'lagged_fibonacci.dart';
import 'rvz_container.dart';
import 'wii_crypto.dart';

/// On-the-fly RVZ/WIA reader. Decompresses only the groups a read touches,
/// applies RVZ unpacking (literal + junk PRNG), and for Wii rebuilds the
/// encrypted partition clusters (hash tree + AES), so rcheevos can hash an RVZ
/// without materialising the ISO. Returns null (declines) for RVZ compression we
/// don't support yet (LZMA/bzip2/purge, or zstd-compressed Wii exception lists).
class RvzReader implements DiscBytesReader {
  static const _junkBlock = 0x8000;
  static const _blockData = WiiCrypto.blockData; // 0x7C00
  static const _blockTotal = WiiCrypto.blockTotal; // 0x8000
  static const _groupDataSize = WiiCrypto.groupDataSize; // 0x1F0000
  static const _groupTotalSize = _blockTotal * WiiCrypto.blocksPerGroup; // 0x200000

  final RandomAccessFile _raf;
  final RvzContainer _c;
  final List<_AlignedRaw> _raw; // raw-data regions in aligned disc space
  final List<_WiiPartition> _partitions;
  final int _chunkDec; // partition chunk size in decrypted (0x7C00) space

  // Cache for the most recently decoded WIA group (raw or partition-decrypted).
  int _cachedGroup = -1;
  Uint8List? _cachedBytes;
  List<HashException>? _cachedExceptions;

  // Cache for the most recently reconstructed 2 MiB encrypted Wii group.
  int _encPartition = -1;
  int _encGroupIndex = -1;
  Uint8List? _encBytes;

  RvzReader._(this._raf, this._c, this._raw, this._partitions, this._chunkDec);

  static RvzReader? open(String path) {
    final raf = File(path).openSync();
    try {
      final c = RvzContainer.open(raf, decompress: _decompress);
      // Supported compression: NONE or Zstandard. (LZMA/LZMA2/bzip2/purge not yet.)
      if (c == null || (c.compression != 0 && c.compression != 5)) {
        raf.closeSync();
        return null;
      }
      // Zstd-compressed Wii exception lists aren't handled yet; decline so the
      // caller falls back to DolphinTool. (Uncompressed exception lists — the
      // common NONE case — are fine.)
      if (c.isWii && c.compression > 1 && c.partitions.isNotEmpty) {
        raf.closeSync();
        return null;
      }

      final raw = [
        for (final r in c.rawData)
          () {
            final aligned = (r.discOffset ~/ _junkBlock) * _junkBlock;
            return _AlignedRaw(
              alignedOffset: aligned,
              adjustedSize: r.size + (r.discOffset - aligned),
              groupIndex: r.groupIndex,
            );
          }()
      ];

      final chunkDec = c.chunkSize * _blockData ~/ _blockTotal;
      final partitions = [
        for (final part in c.partitions)
          () {
            final firstSector = part.data[0].firstSector;
            final pd1 = part.data[1];
            final total = pd1.numSectors != 0
                ? pd1.firstSector - firstSector + pd1.numSectors
                : part.data[0].numSectors;
            return _WiiPartition(
              key: part.key,
              firstSector: firstSector,
              totalSectors: total,
              data: [
                for (final pd in part.data)
                  _PdRegion(
                    discFirstSector: pd.firstSector,
                    decStart: (pd.firstSector - firstSector) * _blockData,
                    numSectors: pd.numSectors,
                    groupIndex: pd.groupIndex,
                  ),
              ],
            );
          }()
      ];
      return RvzReader._(raf, c, raw, partitions, chunkDec);
    } catch (_) {
      try {
        raf.closeSync();
      } catch (_) {}
      return null;
    }
  }

  static Uint8List _decompress(int method, Uint8List src, int dstSize) {
    switch (method) {
      case 0:
        return src;
      case 5:
        final r = RawHash.zstdDecompress(src, dstSize);
        if (r == null) throw const FormatException('zstd decompress failed');
        return r;
      default:
        throw UnsupportedError('RVZ compression method $method');
    }
  }

  @override
  int get length => _c.isoFileSize;

  @override
  Uint8List read(int offset, int len) {
    final out = Uint8List(len);
    var done = 0;
    while (done < len) {
      final pos = offset + done;
      final part = _partitionAt(pos);
      if (part != null) {
        done += _readWiiInto(out, done, part, pos, len - done);
        continue;
      }
      final loc = _locateRaw(pos);
      if (loc == null) {
        done += 1; // outside any known region: zero-fill
        continue;
      }
      final within = pos - loc.groupDiscStart;
      final take = _min(loc.groupSize - within, len - done);
      final (bytes, _) =
          _decodeGroup(loc.groupIndex, loc.groupSize, loc.groupDiscStart, 0);
      final avail = _min(bytes.length - within, take);
      if (avail > 0) out.setRange(done, done + avail, bytes, within);
      done += take;
    }
    return out;
  }

  // ---- Wii partition path ----

  _WiiPartition? _partitionAt(int discOffset) {
    for (final p in _partitions) {
      final start = p.firstSector * _blockTotal;
      if (discOffset >= start && discOffset < start + p.totalSectors * _blockTotal) {
        return p;
      }
    }
    return null;
  }

  // Copies encrypted partition bytes for [discOffset] into [out] at [outPos];
  // returns how many bytes were written (bounded to the current 2 MiB group).
  int _readWiiInto(
      Uint8List out, int outPos, _WiiPartition part, int discOffset, int want) {
    final rel = discOffset - part.firstSector * _blockTotal;
    final groupIndex = rel ~/ _groupTotalSize;
    final within = rel % _groupTotalSize;
    final enc = _encryptedGroup(part, groupIndex);
    final take = _min(_min(_groupTotalSize - within, want), enc.length - within);
    out.setRange(outPos, outPos + take, enc, within);
    return take;
  }

  int _partIndex(_WiiPartition p) => _partitions.indexOf(p);

  Uint8List _encryptedGroup(_WiiPartition part, int groupIndex) {
    final pi = _partIndex(part);
    if (pi == _encPartition && groupIndex == _encGroupIndex) return _encBytes!;

    final decGroupOffset = groupIndex * _groupDataSize;
    final partDecSize = part.totalSectors * _blockData;
    final decData =
        List.generate(WiiCrypto.blocksPerGroup, (_) => Uint8List(_blockData));
    final exceptions = <HashException>[];
    var lastWiaGroup = -1;

    for (var block = 0; block < WiiCrypto.blocksPerGroup; block++) {
      final decOff = decGroupOffset + block * _blockData;
      if (decOff + _blockData > partDecSize) continue; // beyond data: zeros
      final r = _readDecryptedBlock(part, decOff);
      decData[block] = r.data;
      if (r.wiaGroup != lastWiaGroup) {
        exceptions.addAll(r.exceptions);
        lastWiaGroup = r.wiaGroup;
      }
    }

    final enc = WiiCrypto.encryptGroup(decData, part.key, exceptions);
    _encPartition = pi;
    _encGroupIndex = groupIndex;
    _encBytes = enc;
    return enc;
  }

  // Reads one decrypted 0x7C00 block at [decOff] (partition decrypted space),
  // plus the exceptions of the WIA group it came from (offset-adjusted).
  ({Uint8List data, int wiaGroup, List<HashException> exceptions})
      _readDecryptedBlock(_WiiPartition part, int decOff) {
    for (final pd in part.data) {
      final pdEnd = pd.decStart + pd.numSectors * _blockData;
      if (pd.numSectors == 0 || decOff < pd.decStart || decOff >= pdEnd) continue;

      final local = decOff - pd.decStart;
      final i = local ~/ _chunkDec;
      final wiaGroup = pd.groupIndex + i;
      final offsetInGroup = local - i * _chunkDec;
      final junkOffset = i * _chunkDec;
      final exceptionLists = _max(1, _chunkDec ~/ _groupDataSize);
      // Last group of a pd is clamped to the remaining decrypted data.
      final pdDecSize = pd.numSectors * _blockData;
      final outSize = _min(_chunkDec, pdDecSize - i * _chunkDec);

      final (data, rawExc) =
          _decodeGroup(wiaGroup, outSize, junkOffset, exceptionLists);

      // GetHashExceptions shifts each offset so per-chunk hashes land in the
      // right block of the 64-block group.
      final addOffset =
          (junkOffset % _groupDataSize) ~/ _blockData * WiiCrypto.blockHeader;
      final exceptions = addOffset == 0
          ? rawExc
          : [for (final e in rawExc) HashException(e.offset + addOffset, e.hash)];

      return (
        data: Uint8List.sublistView(data, offsetInGroup, offsetInGroup + _blockData),
        wiaGroup: wiaGroup,
        exceptions: exceptions,
      );
    }
    return (data: Uint8List(_blockData), wiaGroup: -1, exceptions: const []);
  }

  // ---- shared group decoding ----

  // Decodes one WIA group to [outSize] bytes at disc/partition [dataOffset],
  // parsing [exceptionLists] uncompressed hash-exception lists from the front
  // when present. Returns the data plus the (unshifted) exceptions.
  (Uint8List, List<HashException>) _decodeGroup(
      int groupIndex, int outSize, int dataOffset, int exceptionLists) {
    if (groupIndex == _cachedGroup) {
      return (_cachedBytes!, _cachedExceptions ?? const []);
    }
    final g = _c.groups[groupIndex];

    Uint8List data;
    List<HashException> exceptions = const [];
    if (g.isAllZero) {
      data = Uint8List(outSize);
    } else {
      _raf.setPositionSync(g.dataOffset);
      var stored = _raf.readSync(g.dataSize);

      if (exceptionLists > 0 && !g.compressed) {
        final parsed = _parseExceptions(stored, exceptionLists);
        exceptions = parsed.$1;
        stored = Uint8List.sublistView(stored, parsed.$2);
      }

      final decompressed = g.compressed
          ? _decompress(_c.compression, stored,
              g.packedSize != 0 ? g.packedSize : outSize)
          : stored;
      data = g.packedSize != 0
          ? _rvzUnpack(decompressed, outSize, dataOffset)
          : decompressed;
    }

    _cachedGroup = groupIndex;
    _cachedBytes = data;
    _cachedExceptions = exceptions;
    return (data, exceptions);
  }

  // Parses [count] hash-exception lists: each is u16 big-endian entry count then
  // entries of (u16 offset, 20-byte hash). The final list is padded to 4 bytes.
  (List<HashException>, int) _parseExceptions(Uint8List data, int count) {
    final exc = <HashException>[];
    var pos = 0;
    for (var l = 0; l < count; l++) {
      final n = (data[pos] << 8) | data[pos + 1];
      pos += 2;
      for (var e = 0; e < n; e++) {
        final off = (data[pos] << 8) | data[pos + 1];
        exc.add(HashException(
            off, Uint8List.fromList(Uint8List.sublistView(data, pos + 2, pos + 22))));
        pos += 22;
      }
      if (l == count - 1) pos = ((pos + 3) ~/ 4) * 4;
    }
    return (exc, pos);
  }

  _Located? _locateRaw(int pos) {
    for (final r in _raw) {
      if (pos < r.alignedOffset || pos >= r.alignedOffset + r.adjustedSize) {
        continue;
      }
      final local = pos - r.alignedOffset;
      final localGroup = local ~/ _c.chunkSize;
      final groupStart = localGroup * _c.chunkSize;
      return _Located(
        groupIndex: r.groupIndex + localGroup,
        groupDiscStart: r.alignedOffset + groupStart,
        groupSize: _min(_c.chunkSize, r.adjustedSize - groupStart),
      );
    }
    return null;
  }

  Uint8List _rvzUnpack(Uint8List packed, int outSize, int dataOffset) {
    final out = Uint8List(outSize);
    final bd = ByteData.sublistView(packed);
    var inPos = 0;
    var outPos = 0;
    while (outPos < outSize) {
      final raw = bd.getUint32(inPos, Endian.big);
      inPos += 4;
      final size = raw & 0x7fffffff;
      if (raw & 0x80000000 != 0) {
        final lfg = LaggedFibonacciGenerator(
            Uint8List.sublistView(packed, inPos, inPos + 68));
        inPos += 68;
        lfg.forward((dataOffset + outPos) % _junkBlock);
        lfg.getBytes(size, out, outPos);
      } else {
        out.setRange(outPos, outPos + size, packed, inPos);
        inPos += size;
      }
      outPos += size;
    }
    return out;
  }

  @override
  void close() => _raf.closeSync();

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}

class _AlignedRaw {
  final int alignedOffset;
  final int adjustedSize;
  final int groupIndex;
  const _AlignedRaw({
    required this.alignedOffset,
    required this.adjustedSize,
    required this.groupIndex,
  });
}

class _Located {
  final int groupIndex;
  final int groupDiscStart;
  final int groupSize;
  const _Located({
    required this.groupIndex,
    required this.groupDiscStart,
    required this.groupSize,
  });
}

class _WiiPartition {
  final Uint8List key;
  final int firstSector; // partition data start, in disc sectors
  final int totalSectors;
  final List<_PdRegion> data;
  const _WiiPartition({
    required this.key,
    required this.firstSector,
    required this.totalSectors,
    required this.data,
  });
}

class _PdRegion {
  final int discFirstSector;
  final int decStart; // decrypted-space start offset within the partition
  final int numSectors;
  final int groupIndex;
  const _PdRegion({
    required this.discFirstSector,
    required this.decStart,
    required this.numSectors,
    required this.groupIndex,
  });
}
