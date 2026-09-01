import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/disc_reader.dart';

// Builds a Dolphin GCZ: 32-byte LE header (magic 0xB10BC001), a num_blocks u64
// block-pointer table (MSB flags an uncompressed block), a u32 adler table we
// don't read back, then the block data. Block 1 is stored raw, 0 and 2 zlib.
File _writeGcz(Directory dir, {required int blockSize}) {
  final blocks = [_block(0x10), _block(0x20), _block(0x30)];
  final stored = <Uint8List>[
    Uint8List.fromList(zlib.encode(blocks[0])),
    blocks[1], // raw
    Uint8List.fromList(zlib.encode(blocks[2])),
  ];
  final raw = [false, true, false];

  final data = BytesBuilder();
  final pointers = <int>[];
  var off = 0;
  for (var i = 0; i < stored.length; i++) {
    pointers.add(raw[i] ? (off | (1 << 63)) : off);
    data.add(stored[i]);
    off += stored[i].length;
  }
  final compressedData = data.toBytes();

  final header = ByteData(32);
  header.setUint32(0, 0xB10BC001, Endian.little);
  header.setUint32(4, 0, Endian.little); // sub_type
  header.setUint64(8, compressedData.length, Endian.little);
  header.setUint64(16, blocks.length * blockSize, Endian.little); // data_size
  header.setUint32(24, blockSize, Endian.little);
  header.setUint32(28, blocks.length, Endian.little);

  final out = BytesBuilder();
  out.add(header.buffer.asUint8List());
  final ptrTable = ByteData(pointers.length * 8);
  for (var i = 0; i < pointers.length; i++) {
    ptrTable.setUint64(i * 8, pointers[i], Endian.little);
  }
  out.add(ptrTable.buffer.asUint8List());
  out.add(Uint8List(pointers.length * 4)); // adler32 table, unread
  out.add(compressedData);

  final f = File('${dir.path}/test.gcz')..writeAsBytesSync(out.toBytes());
  return f;
}

// A recognisable 8-byte block whose bytes are all [tag].
Uint8List _block(int tag) => Uint8List(8)..fillRange(0, 8, tag);
final _zeros = Uint8List(8);

// Builds a Dolphin-style CISO: 4-byte "CISO" magic, u32 LE block size, a
// 32760-byte present/absent map (one byte per block), then the present blocks
// stored back-to-back. Here block 1 is absent so it must read back as zeros.
File _writeCiso(Directory dir, {required int blockSize}) {
  const headerSize = 0x8000;
  final present = [1, 0, 1, 1]; // block 1 sparse
  final blocks = {0: _block(0x10), 2: _block(0x20), 3: _block(0x30)};

  final header = Uint8List(headerSize);
  header.setAll(0, 'CISO'.codeUnits);
  final bd = ByteData.sublistView(header);
  bd.setUint32(4, blockSize, Endian.little);
  for (var i = 0; i < present.length; i++) {
    header[8 + i] = present[i];
  }

  final out = <int>[...header];
  for (var i = 0; i < present.length; i++) {
    if (present[i] == 1) out.addAll(blocks[i]!);
  }
  final f = File('${dir.path}/test.ciso')..writeAsBytesSync(out);
  return f;
}

// Builds a single-disc WBFS: "WBFS" magic, big-endian hd_sector_count, the two
// shift bytes, then disc 0's wlba table (big-endian u16) at hd_sector_size+256.
// 128 KiB wbfs sectors keep the whole wlba table inside file sector 0, so the
// two data sectors sit at file sectors 1 and 2. Logical cluster 2 is absent.
File _writeWbfs(Directory dir) {
  const hdShift = 9; // 512-byte hd sectors
  const wbfsShift = 17; // 128 KiB wbfs sectors
  const wiiSectorSize = 0x8000;
  const wiiSectorCount = 143432; // single-layer Wii disc
  final s = 1 << wbfsShift;
  final hdSecSize = 1 << hdShift;
  final blocksPerDisc = (wiiSectorCount * wiiSectorSize + s - 1) ~/ s;

  final file = Uint8List(3 * s);
  file.setAll(0, 'WBFS'.codeUnits);
  final bd = ByteData.sublistView(file);
  bd.setUint32(4, 1024, Endian.big); // hd_sector_count (arbitrary)
  file[8] = hdShift;
  file[9] = wbfsShift;

  final tableOff = hdSecSize + 256;
  bd.setUint16(tableOff + 0, 1, Endian.big); // logical cluster 0 -> file sec 1
  bd.setUint16(tableOff + 2, 2, Endian.big); // logical cluster 1 -> file sec 2
  bd.setUint16(tableOff + 4, 0, Endian.big); // logical cluster 2 -> absent

  file.setAll(1 * s, _block(0x10));
  file.setAll(2 * s, _block(0x20));
  assert(blocksPerDisc * 2 < s); // table must stay inside file sector 0

  final f = File('${dir.path}/test.wbfs')..writeAsBytesSync(file);
  return f;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('disc_reader'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('CisoReader', () {
    test('reads present blocks and zero-fills absent ones', () {
      final reader = openDiscReader(_writeCiso(tmp, blockSize: 8).path)!;
      addTearDown(reader.close);

      expect(reader.length, 32); // 4 blocks * 8 bytes
      expect(reader.read(0, 8), _block(0x10));
      expect(reader.read(8, 8), _zeros); // sparse block 1
      expect(reader.read(16, 8), _block(0x20));
      expect(reader.read(24, 8), _block(0x30));
    });

    test('reads spanning a block boundary into an absent block', () {
      final reader = openDiscReader(_writeCiso(tmp, blockSize: 8).path)!;
      addTearDown(reader.close);

      // Last 4 bytes of block 0, then first 4 of the sparse block 1.
      final expected = Uint8List.fromList([...List.filled(4, 0x10), 0, 0, 0, 0]);
      expect(reader.read(4, 8), expected);
    });

    test('reads past the end zero-fill', () {
      final reader = openDiscReader(_writeCiso(tmp, blockSize: 8).path)!;
      addTearDown(reader.close);

      expect(reader.read(28, 8),
          Uint8List.fromList([...List.filled(4, 0x30), 0, 0, 0, 0]));
    });
  });

  group('GczReader', () {
    test('inflates compressed blocks and copies raw ones', () {
      final reader = openDiscReader(_writeGcz(tmp, blockSize: 8).path)!;
      addTearDown(reader.close);

      expect(reader.length, 24); // 3 blocks * 8
      expect(reader.read(0, 8), _block(0x10)); // zlib block
      expect(reader.read(8, 8), _block(0x20)); // raw block
      expect(reader.read(16, 8), _block(0x30)); // zlib block
    });

    test('reads spanning a block boundary', () {
      final reader = openDiscReader(_writeGcz(tmp, blockSize: 8).path)!;
      addTearDown(reader.close);

      expect(reader.read(4, 8),
          Uint8List.fromList([...List.filled(4, 0x10), ...List.filled(4, 0x20)]));
    });
  });

  group('WbfsReader', () {
    test('maps logical clusters through the wlba table', () {
      final reader = openDiscReader(_writeWbfs(tmp).path)!;
      addTearDown(reader.close);
      const s = 1 << 17;

      expect(reader.read(0, 8), _block(0x10)); // cluster 0 -> file sector 1
      expect(reader.read(s, 8), _block(0x20)); // cluster 1 -> file sector 2
      expect(reader.read(2 * s, 8), _zeros); // cluster 2 -> absent (wlba 0)
    });
  });
}
