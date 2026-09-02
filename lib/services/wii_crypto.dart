import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'aes.dart';

/// Rebuilds encrypted Wii disc clusters from decrypted RVZ data, matching
/// Dolphin's `VolumeWii::HashGroup` + `EncryptGroup`. A group is 64 clusters;
/// each cluster is a 0x400 hash block + 0x7C00 data, both AES-CBC encrypted with
/// the partition key (hash block IV=0; data IV = encrypted hash bytes at 0x3D0).
class WiiCrypto {
  static const blockHeader = 0x400;
  static const blockData = 0x7c00;
  static const blockTotal = 0x8000;
  static const blocksPerGroup = 64;
  static const groupDataSize = blockData * blocksPerGroup; // 0x1F0000

  /// [decData] is 64 decrypted 0x7C00 blocks; [exceptions] replace recomputed
  /// hashes at their (group-relative) offsets. Returns 64 × 0x8000 encrypted.
  static Uint8List encryptGroup(
      List<Uint8List> decData, Uint8List key, List<HashException> exceptions) {
    final hashBlocks =
        List.generate(blocksPerGroup, (_) => Uint8List(blockHeader));

    // H0: SHA-1 of each of the 31 0x400 sub-blocks of a cluster's data.
    for (var i = 0; i < blocksPerGroup; i++) {
      for (var j = 0; j < 31; j++) {
        final d = crypto.sha1
            .convert(Uint8List.sublistView(decData[i], j * 0x400, j * 0x400 + 0x400))
            .bytes;
        hashBlocks[i].setRange(j * 20, j * 20 + 20, d);
      }
    }
    // H1: per 8-cluster subgroup, SHA-1 of each cluster's 620-byte H0 region;
    // the 8-hash H1 block (at 0x280) is identical across the subgroup.
    for (var base = 0; base < blocksPerGroup; base += 8) {
      final h1 = Uint8List(160);
      for (var k = 0; k < 8; k++) {
        final d = crypto.sha1
            .convert(Uint8List.sublistView(hashBlocks[base + k], 0, 620))
            .bytes;
        h1.setRange(k * 20, k * 20 + 20, d);
      }
      for (var k = 0; k < 8; k++) {
        hashBlocks[base + k].setRange(0x280, 0x280 + 160, h1);
      }
    }
    // H2: SHA-1 of each subgroup's 160-byte H1 block; the 8-hash H2 block (at
    // 0x340) is identical across all 64 clusters.
    final h2 = Uint8List(160);
    for (var m = 0; m < 8; m++) {
      final d = crypto.sha1
          .convert(Uint8List.sublistView(hashBlocks[m * 8], 0x280, 0x280 + 160))
          .bytes;
      h2.setRange(m * 20, m * 20 + 20, d);
    }
    for (var i = 0; i < blocksPerGroup; i++) {
      hashBlocks[i].setRange(0x340, 0x340 + 160, h2);
    }

    // Apply RVZ hash exceptions (offsets are within the 64-block group).
    for (final e in exceptions) {
      final bi = e.offset ~/ blockHeader;
      final off = e.offset % blockHeader;
      if (bi < blocksPerGroup && off + 20 <= blockHeader) {
        hashBlocks[bi].setRange(off, off + 20, e.hash);
      }
    }

    final aes = Aes128(key);
    final zeroIv = Uint8List(16);
    final out = Uint8List(blocksPerGroup * blockTotal);
    for (var j = 0; j < blocksPerGroup; j++) {
      final encHash = aes.cbcEncrypt(hashBlocks[j], zeroIv);
      final dataIv = Uint8List.fromList(
          Uint8List.sublistView(encHash, 0x3d0, 0x3e0));
      final encData = aes.cbcEncrypt(decData[j], dataIv);
      out.setRange(j * blockTotal, j * blockTotal + blockHeader, encHash);
      out.setRange(j * blockTotal + blockHeader, (j + 1) * blockTotal, encData);
    }
    return out;
  }
}

/// A recomputed-hash override: [hash] (20 bytes) belongs at byte [offset] within
/// the group's hash region (block = offset / 0x400, within-block = offset % 0x400).
class HashException {
  final int offset;
  final Uint8List hash;
  const HashException(this.offset, this.hash);
}
