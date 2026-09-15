import 'dart:typed_data';

/// Minimal AES-128 (FIPS-197) with CBC encryption, enough to reconstruct Wii
/// partition clusters. Keys are 16 bytes; blocks are 16 bytes. Not constant-time,
/// fine for offline hashing, never use for secrets in a hostile timing context.
class Aes128 {
  final Uint8List _roundKeys; // 176 bytes = 11 round keys

  Aes128(Uint8List key) : _roundKeys = _expandKey(key) {
    if (key.length != 16) throw ArgumentError('AES-128 key must be 16 bytes');
  }

  /// CBC-encrypts [data] (a multiple of 16 bytes) with initial vector [iv].
  Uint8List cbcEncrypt(Uint8List data, Uint8List iv) {
    final out = Uint8List(data.length);
    final prev = Uint8List.fromList(iv);
    final block = Uint8List(16);
    for (var off = 0; off < data.length; off += 16) {
      for (var i = 0; i < 16; i++) {
        block[i] = data[off + i] ^ prev[i];
      }
      final enc = _encryptBlock(block);
      out.setRange(off, off + 16, enc);
      prev.setRange(0, 16, enc);
    }
    return out;
  }

  Uint8List _encryptBlock(Uint8List input) {
    final s = Uint8List.fromList(input);
    _addRoundKey(s, 0);
    for (var round = 1; round < 10; round++) {
      _subBytes(s, _sbox);
      _shiftRows(s);
      _mixColumns(s);
      _addRoundKey(s, round);
    }
    _subBytes(s, _sbox);
    _shiftRows(s);
    _addRoundKey(s, 10);
    return s;
  }

  void _addRoundKey(Uint8List s, int round) {
    final base = round * 16;
    for (var i = 0; i < 16; i++) {
      s[i] ^= _roundKeys[base + i];
    }
  }

  static void _subBytes(Uint8List s, Uint8List box) {
    for (var i = 0; i < 16; i++) {
      s[i] = box[s[i]];
    }
  }

  // State is column-major (AES standard): byte i is row i%4, col i~/4.
  static void _shiftRows(Uint8List s) {
    final t = Uint8List.fromList(s);
    for (var r = 1; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        s[r + 4 * c] = t[r + 4 * ((c + r) % 4)];
      }
    }
  }

  static void _mixColumns(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final i = 4 * c;
      final a0 = s[i], a1 = s[i + 1], a2 = s[i + 2], a3 = s[i + 3];
      s[i] = _x2(a0) ^ _x3(a1) ^ a2 ^ a3;
      s[i + 1] = a0 ^ _x2(a1) ^ _x3(a2) ^ a3;
      s[i + 2] = a0 ^ a1 ^ _x2(a2) ^ _x3(a3);
      s[i + 3] = _x3(a0) ^ a1 ^ a2 ^ _x2(a3);
    }
  }

  static int _x2(int b) {
    final s = b << 1;
    return (s ^ ((s >> 8) * 0x1b)) & 0xff;
  }

  static int _x3(int b) => _x2(b) ^ b;

  // GF(2^8) multiply.
  static int _mul(int a, int b) {
    var result = 0;
    var aa = a, bb = b;
    for (var i = 0; i < 8; i++) {
      if (bb & 1 != 0) result ^= aa;
      final hi = aa & 0x80;
      aa = (aa << 1) & 0xff;
      if (hi != 0) aa ^= 0x1b;
      bb >>= 1;
    }
    return result & 0xff;
  }

  static Uint8List _expandKey(Uint8List key) {
    final rk = Uint8List(176);
    rk.setRange(0, 16, key);
    var rcon = 1;
    for (var i = 16; i < 176; i += 4) {
      var t0 = rk[i - 4], t1 = rk[i - 3], t2 = rk[i - 2], t3 = rk[i - 1];
      if (i % 16 == 0) {
        // RotWord + SubWord + Rcon
        final tmp = t0;
        t0 = _sbox[t1] ^ rcon;
        t1 = _sbox[t2];
        t2 = _sbox[t3];
        t3 = _sbox[tmp];
        rcon = _x2(rcon);
      }
      rk[i] = rk[i - 16] ^ t0;
      rk[i + 1] = rk[i - 15] ^ t1;
      rk[i + 2] = rk[i - 14] ^ t2;
      rk[i + 3] = rk[i - 13] ^ t3;
    }
    return rk;
  }

  static final Uint8List _sbox = _buildSbox();

  // Generates the AES S-box from first principles (inverse in GF(2^8) + affine),
  // so we don't hand-transcribe a 256-entry table.
  static Uint8List _buildSbox() {
    final box = Uint8List(256);
    // multiplicative inverse table
    final inv = Uint8List(256);
    for (var a = 1; a < 256; a++) {
      for (var b = 1; b < 256; b++) {
        if (_mul(a, b) == 1) {
          inv[a] = b;
          break;
        }
      }
    }
    for (var i = 0; i < 256; i++) {
      final x = inv[i];
      var s = x;
      for (var r = 0; r < 4; r++) {
        s ^= ((x << (r + 1)) | (x >> (7 - r))) & 0xff;
      }
      box[i] = s ^ 0x63;
    }
    return box;
  }
}
