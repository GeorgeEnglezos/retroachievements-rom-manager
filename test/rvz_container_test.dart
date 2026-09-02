import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/rvz_container.dart';

// Identity "decompress" for NONE-compressed tables (method 0).
Uint8List _none(int method, Uint8List src, int dstSize) {
  if (method != 0) throw 'unexpected compression $method';
  return src;
}

// Builds a minimal RVZ with NONE compression so the tables are stored raw and
// the parser can be exercised with no native decompressor. Offsets follow
// docs/WiaAndRvz.md; all integers big-endian.
File _writeRvz(Directory dir) {
  const discSize = 0xdc; // through compr_data[7]
  const partOff = 0x48 + discSize; // 0x124
  const rawOff = partOff + 48; // one 48-byte partition
  const groupOff = rawOff + 2 * 24; // two raw-data entries

  final file = BytesBuilder();

  // ---- file head (0x48) ----
  final head = ByteData(0x48);
  head.setUint8(0, 0x52); // R
  head.setUint8(1, 0x56); // V
  head.setUint8(2, 0x5a); // Z
  head.setUint8(3, 0x01);
  head.setUint32(0x0c, discSize, Endian.big);
  head.setUint64(0x24, 0x57058000, Endian.big); // iso_file_size (~1.4 GiB)
  file.add(head.buffer.asUint8List());

  // ---- disc struct (discSize) ----
  final disc = ByteData(discSize);
  disc.setUint32(0x00, 2, Endian.big); // disc_type = Wii
  disc.setUint32(0x04, 0, Endian.big); // compression = NONE
  disc.setUint32(0x08, 0, Endian.big); // level
  disc.setUint32(0x0c, 0x200000, Endian.big); // chunk_size = 2 MiB
  for (var i = 0; i < 0x80; i++) {
    disc.setUint8(0x10 + i, i & 0xff); // dhead marker
  }
  disc.setUint32(0x90, 1, Endian.big); // n_part
  disc.setUint32(0x94, 48, Endian.big); // part_t_size
  disc.setUint64(0x98, partOff, Endian.big);
  disc.setUint32(0xb4, 2, Endian.big); // n_raw_data
  disc.setUint64(0xb8, rawOff, Endian.big);
  disc.setUint32(0xc0, 2 * 24, Endian.big); // raw_data_size (NONE = raw)
  disc.setUint32(0xc4, 3, Endian.big); // n_groups
  disc.setUint64(0xc8, groupOff, Endian.big);
  disc.setUint32(0xd0, 3 * 12, Endian.big); // group_size (NONE = raw)
  disc.setUint8(0xd4, 0); // compr_data_len
  file.add(disc.buffer.asUint8List());

  // ---- partition table (uncompressed) ----
  final part = ByteData(48);
  for (var i = 0; i < 16; i++) {
    part.setUint8(i, 0xab); // key
  }
  part.setUint32(16, 0, Endian.big); // pd0 first_sector
  part.setUint32(20, 0x20, Endian.big); // pd0 n_sectors
  part.setUint32(24, 0, Endian.big); // pd0 group_index
  part.setUint32(28, 1, Endian.big); // pd0 n_groups
  part.setUint32(32, 0x20, Endian.big); // pd1 first_sector
  part.setUint32(36, 0x100, Endian.big); // pd1 n_sectors
  part.setUint32(40, 1, Endian.big); // pd1 group_index
  part.setUint32(44, 5, Endian.big); // pd1 n_groups
  file.add(part.buffer.asUint8List());

  // ---- raw-data table ----
  final raw = ByteData(2 * 24);
  raw.setUint64(0, 0, Endian.big); // [0] disc_offset
  raw.setUint64(8, 0x40000, Endian.big); // [0] size
  raw.setUint32(16, 0, Endian.big); // [0] group_index
  raw.setUint32(20, 1, Endian.big); // [0] n_groups
  raw.setUint64(24, 0x40000, Endian.big); // [1] disc_offset
  raw.setUint64(32, 0x8000, Endian.big); // [1] size
  raw.setUint32(40, 1, Endian.big); // [1] group_index
  raw.setUint32(44, 2, Endian.big); // [1] n_groups
  file.add(raw.buffer.asUint8List());

  // ---- group table (RVZ, 12 bytes each) ----
  final grp = ByteData(3 * 12);
  grp.setUint32(0, 0x100, Endian.big); // g0 data_off4 -> offset 0x400
  grp.setUint32(4, 0x80000010, Endian.big); // g0 compressed, size 0x10
  grp.setUint32(8, 0x20000, Endian.big); // g0 packed_size
  grp.setUint32(12, 0x200, Endian.big); // g1 data_off4 -> 0x800
  grp.setUint32(16, 0x40, Endian.big); // g1 NOT compressed, size 0x40
  grp.setUint32(20, 0, Endian.big); // g1 packed_size (unused)
  grp.setUint32(24, 0, Endian.big); // g2 data_off4
  grp.setUint32(28, 0, Endian.big); // g2 data_size 0 => all zeros
  grp.setUint32(32, 0, Endian.big); // g2 packed_size
  file.add(grp.buffer.asUint8List());

  final f = File('${dir.path}/test.rvz')..writeAsBytesSync(file.toBytes());
  return f;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('rvz'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('parses RVZ header, disc descriptor, and all three tables', () {
    final raf = _writeRvz(tmp).openSync();
    addTearDown(raf.closeSync);
    final c = RvzContainer.open(raf, decompress: _none)!;

    expect(c.isWii, isTrue);
    expect(c.compression, 0);
    expect(c.chunkSize, 0x200000);
    expect(c.isoFileSize, 0x57058000);

    expect(c.rawData, hasLength(2));
    expect(c.rawData[1].discOffset, 0x40000);
    expect(c.rawData[1].size, 0x8000);
    expect(c.rawData[1].numGroups, 2);

    expect(c.partitions, hasLength(1));
    expect(c.partitions[0].key.every((b) => b == 0xab), isTrue);
    expect(c.partitions[0].data[1].firstSector, 0x20);
    expect(c.partitions[0].data[1].numGroups, 5);

    expect(c.groups, hasLength(3));
    expect(c.groups[0].dataOffset, 0x400); // 0x100 * 4
    expect(c.groups[0].compressed, isTrue);
    expect(c.groups[0].dataSize, 0x10); // MSB stripped
    expect(c.groups[0].packedSize, 0x20000);
    expect(c.groups[1].compressed, isFalse);
    expect(c.groups[1].dataSize, 0x40);
    expect(c.groups[2].isAllZero, isTrue);
  });

  test('rejects a non-WIA/RVZ file', () {
    final f = File('${tmp.path}/x.bin')..writeAsBytesSync(Uint8List(0x48));
    final raf = f.openSync();
    addTearDown(raf.closeSync);
    expect(RvzContainer.open(raf, decompress: _none), isNull);
  });
}
