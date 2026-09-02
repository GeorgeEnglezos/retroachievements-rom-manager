import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/lagged_fibonacci.dart';

Uint8List _seed() =>
    Uint8List.fromList(List.generate(68, (i) => (i * 7 + 1) & 0xff));

Uint8List _gen(int count, {int skip = 0}) {
  final lfg = LaggedFibonacciGenerator(_seed());
  if (skip > 0) lfg.forward(skip);
  final out = Uint8List(count);
  lfg.getBytes(count, out, 0);
  return out;
}

void main() {
  test('is deterministic for a given seed', () {
    expect(_gen(4096), _gen(4096));
  });

  test('forward(n) skips exactly the first n bytes of the stream', () {
    final full = _gen(4096);
    final skipped = _gen(4096 - 1000, skip: 1000);
    expect(skipped, full.sublist(1000));
  });

  test('matches a real Dolphin RVZ junk vector (seed + forward)', () {
    // Captured from a real Wii RVZ vs DolphinTool ISO: this 68-byte seed,
    // forwarded 0x7000 bytes, must produce these 32 bytes. Locks the exact
    // Initialize (raw fill, then transform+byteswap all words) and Forward.
    final seed = Uint8List.fromList([
      for (final h in [
        '65efea99', 'f3ff48e2', '6ae75678', '33ee86b3', 'e2049e76', '27fecfd4',
        '24650398', 'dd2e1b0e', 'ac5ec676', 'a3a3a5db', '439715f5', '204c6e9c',
        '460b799c', '71498a7a', '044b56bc', 'e6ae72d4', '33c12f50'
      ])
        ...[
          int.parse(h.substring(0, 2), radix: 16),
          int.parse(h.substring(2, 4), radix: 16),
          int.parse(h.substring(4, 6), radix: 16),
          int.parse(h.substring(6, 8), radix: 16),
        ]
    ]);
    final lfg = LaggedFibonacciGenerator(seed);
    lfg.forward(0x7000);
    final out = Uint8List(32);
    lfg.getBytes(32, out, 0);
    final hex = out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex,
        '87fe138b16831fff91599ae50c091353b295f784f6b0eba5ffc164db354e3f0b');
  });

  test('generates across the 2084-byte buffer refill boundary', () {
    // _k*4 = 2084; a >2084 request forces an internal state advance mid-stream.
    final a = _gen(5000);
    final b = _gen(5000);
    expect(a, b);
    expect(a.length, 5000);
  });
}
