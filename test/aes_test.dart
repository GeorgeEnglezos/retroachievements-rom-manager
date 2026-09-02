import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/aes.dart';

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String _hexOf(Uint8List b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('FIPS-197 AES-128 single-block known answer', () {
    // IV=0 CBC over one block reduces to ECB for that block.
    final aes = Aes128(_hex('000102030405060708090a0b0c0d0e0f'));
    final pt = _hex('00112233445566778899aabbccddeeff');
    final ct = aes.cbcEncrypt(pt, Uint8List(16));
    expect(_hexOf(ct), '69c4e0d86a7b0430d8cdb78070b4c55a');
    expect(_hexOf(aes.cbcDecrypt(ct, Uint8List(16))), _hexOf(pt));
  });

  test('NIST SP800-38A CBC-AES128 multi-block known answer', () {
    final aes = Aes128(_hex('2b7e151628aed2a6abf7158809cf4f3c'));
    final iv = _hex('000102030405060708090a0b0c0d0e0f');
    final pt = _hex('6bc1bee22e409f96e93d7e117393172a'
        'ae2d8a571e03ac9c9eb76fac45af8e51');
    final ct = aes.cbcEncrypt(pt, iv);
    expect(_hexOf(ct),
        '7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b2');
    expect(_hexOf(aes.cbcDecrypt(ct, iv)), _hexOf(pt));
  });
}
