import 'dart:io';
import 'dart:typed_data';

/// Parsed WIA/RVZ container metadata: the file head, disc descriptor, and the
/// three tables (raw-data, partitions, groups). This is structure only — group
/// decompression and disc reconstruction live in `RvzReader` (later units).
///
/// Layout reference: Dolphin `docs/WiaAndRvz.md`. All integers are big-endian.
class RvzContainer {
  static const _fileHeadSize = 0x48;

  /// 1 = GameCube, 2 = Wii.
  final int discType;

  /// 0 NONE, 1 PURGE, 2 BZIP2, 3 LZMA, 4 LZMA2, 5 Zstandard (RVZ only).
  final int compression;

  /// Group chunk size in bytes (RVZ: power of two, >= 32 KiB).
  final int chunkSize;

  /// Original (reconstructed) disc size in bytes.
  final int isoFileSize;

  final List<RvzRawData> rawData;
  final List<RvzPartition> partitions;
  final List<RvzGroup> groups;

  RvzContainer._({
    required this.discType,
    required this.compression,
    required this.chunkSize,
    required this.isoFileSize,
    required this.rawData,
    required this.partitions,
    required this.groups,
  });

  bool get isGameCube => discType == 1;
  bool get isWii => discType == 2;

  /// Parses the header and tables from [raf]. Returns null if [raf] isn't a
  /// WIA/RVZ file. The [raf] position is left undefined. Decompresses the
  /// raw-data and group tables with [decompress] (identity for NONE).
  static RvzContainer? open(
    RandomAccessFile raf, {
    required Uint8List Function(int method, Uint8List src, int dstSize)
        decompress,
  }) {
    raf.setPositionSync(0);
    final head = raf.readSync(_fileHeadSize);
    if (head.length < _fileHeadSize) return null;
    // magic: "WIA\x01" or "RVZ\x01"
    final isWia = head[0] == 0x57 && head[1] == 0x49 && head[2] == 0x41;
    final isRvz = head[0] == 0x52 && head[1] == 0x56 && head[2] == 0x5A;
    if ((!isWia && !isRvz) || head[3] != 0x01) return null;

    final fh = ByteData.sublistView(head);
    final discSize = fh.getUint32(0x0c, Endian.big);
    // magic(4) version(4) version_compatible(4) disc_size(4) disc_hash(20) →
    // iso_file_size u64 at 0x24.
    final isoFileSize = fh.getUint64(0x24, Endian.big);

    raf.setPositionSync(_fileHeadSize);
    final disc = ByteData.sublistView(raf.readSync(discSize));

    final discType = disc.getUint32(0x00, Endian.big);
    final compression = disc.getUint32(0x04, Endian.big);
    final chunkSize = disc.getUint32(0x0c, Endian.big);

    var o = 0x90; // after disc_type/compression/level/chunk_size and dhead[0x80]
    final nPart = disc.getUint32(o, Endian.big);
    final partTSize = disc.getUint32(o + 4, Endian.big);
    final partOff = disc.getUint64(o + 8, Endian.big);
    o += 8 + 8 + 20; // n_part, part_t_size, part_off, part_hash
    final nRawData = disc.getUint32(o, Endian.big);
    final rawDataOff = disc.getUint64(o + 4, Endian.big);
    final rawDataSize = disc.getUint32(o + 12, Endian.big);
    o += 16;
    final nGroups = disc.getUint32(o, Endian.big);
    final groupOff = disc.getUint64(o + 4, Endian.big);
    final groupSize = disc.getUint32(o + 12, Endian.big);

    // Raw-data and group tables are compressed with the disc compression;
    // partition structs are stored uncompressed.
    final rawData = _parseRawData(
        decompress(compression, _read(raf, rawDataOff, rawDataSize),
            nRawData * RvzRawData.byteSize),
        nRawData);
    final partitions = _parsePartitions(
        _read(raf, partOff, nPart * partTSize), nPart, partTSize);
    final groups = _parseGroups(
        decompress(compression, _read(raf, groupOff, groupSize),
            nGroups * (isRvz ? RvzGroup.rvzByteSize : RvzGroup.wiaByteSize)),
        nGroups,
        isRvz);

    return RvzContainer._(
      discType: discType,
      compression: compression,
      chunkSize: chunkSize,
      isoFileSize: isoFileSize,
      rawData: rawData,
      partitions: partitions,
      groups: groups,
    );
  }

  static Uint8List _read(RandomAccessFile raf, int offset, int size) {
    raf.setPositionSync(offset);
    return raf.readSync(size);
  }

  static List<RvzRawData> _parseRawData(Uint8List bytes, int n) {
    final bd = ByteData.sublistView(bytes);
    return List.generate(n, (i) {
      final b = i * RvzRawData.byteSize;
      return RvzRawData(
        discOffset: bd.getUint64(b, Endian.big),
        size: bd.getUint64(b + 8, Endian.big),
        groupIndex: bd.getUint32(b + 16, Endian.big),
        numGroups: bd.getUint32(b + 20, Endian.big),
      );
    });
  }

  static List<RvzPartition> _parsePartitions(
      Uint8List bytes, int n, int partTSize) {
    final bd = ByteData.sublistView(bytes);
    return List.generate(n, (i) {
      final b = i * partTSize;
      RvzPartitionData pd(int at) => RvzPartitionData(
            firstSector: bd.getUint32(at, Endian.big),
            numSectors: bd.getUint32(at + 4, Endian.big),
            groupIndex: bd.getUint32(at + 8, Endian.big),
            numGroups: bd.getUint32(at + 12, Endian.big),
          );
      return RvzPartition(
        key: Uint8List.fromList(Uint8List.sublistView(bytes, b, b + 16)),
        data: [pd(b + 16), pd(b + 32)],
      );
    });
  }

  static List<RvzGroup> _parseGroups(Uint8List bytes, int n, bool isRvz) {
    final bd = ByteData.sublistView(bytes);
    final stride = isRvz ? RvzGroup.rvzByteSize : RvzGroup.wiaByteSize;
    return List.generate(n, (i) {
      final b = i * stride;
      final dataOff4 = bd.getUint32(b, Endian.big);
      final rawSize = bd.getUint32(b + 4, Endian.big);
      // WIA: whole field is the size, no compression flag (NONE handled by
      // data_size==0 => all zeros). RVZ: MSB flags compression.
      final compressed = isRvz && (rawSize & 0x80000000) != 0;
      return RvzGroup(
        dataOffset: dataOff4 * 4,
        dataSize: isRvz ? (rawSize & 0x7fffffff) : rawSize,
        compressed: compressed,
        packedSize: isRvz ? bd.getUint32(b + 8, Endian.big) : 0,
      );
    });
  }
}

/// One raw (non-partition) disc region, covered by [numGroups] groups.
class RvzRawData {
  static const byteSize = 24;
  final int discOffset;
  final int size;
  final int groupIndex;
  final int numGroups;
  const RvzRawData({
    required this.discOffset,
    required this.size,
    required this.groupIndex,
    required this.numGroups,
  });
}

/// A Wii partition: its AES title key and two data segments (management + data).
class RvzPartition {
  final Uint8List key;
  final List<RvzPartitionData> data;
  const RvzPartition({required this.key, required this.data});
}

class RvzPartitionData {
  final int firstSector;
  final int numSectors;
  final int groupIndex;
  final int numGroups;
  const RvzPartitionData({
    required this.firstSector,
    required this.numSectors,
    required this.groupIndex,
    required this.numGroups,
  });
}

/// One compressed group. [dataOffset] is the file offset of its stored bytes,
/// [dataSize] the stored (compressed or raw) length, [compressed] whether the
/// disc compression was applied, [packedSize] the size before RVZ unpacking
/// (0 = not RVZ-packed).
class RvzGroup {
  static const wiaByteSize = 8;
  static const rvzByteSize = 12;
  final int dataOffset;
  final int dataSize;
  final bool compressed;
  final int packedSize;
  const RvzGroup({
    required this.dataOffset,
    required this.dataSize,
    required this.compressed,
    required this.packedSize,
  });

  bool get isAllZero => dataSize == 0;
}
