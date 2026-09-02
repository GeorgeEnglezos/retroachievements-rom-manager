// Desktop verification harness for on-device GC/Wii disc hashing (Phase 1).
//
// Run (close the app first so the DLL isn't locked):
//   flutter run -d windows -t tool/disc_hash_check.dart
//
// For the first .rvz it finds in each folder it builds a reference and three
// containers, then checks every Phase 1 reader against it:
//   reference = DolphinTool .rvz->.iso, hashed by the shipping RawHash.hashFile
//               (the canonical RA hash).
//   GCZ  = DolphinTool .rvz->.gcz (a REAL Dolphin container)   -> GczReader
//   CISO = the .iso repacked to CISO in Dart                   -> CisoReader
//   WBFS = the .iso repacked to WBFS in Dart                   -> WbfsReader
// Each container is hashed through RawHash.hashFileVirtual and compared to the
// reference. PASS means the virtual reader + FFI + rcheevos reproduce the real
// disc's hash. The GCZ leg also proves format-compat with a real tool's output.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:rarm/services/disc_reader.dart' show openDiscReader;
import 'package:raw_hash/raw_hash.dart';

const _dolphinTool =
    r'C:\Users\geggl\AppData\Roaming\EmuDeck\Emulators\Dolphin-x64\DolphinTool.exe';
const _gcDir = r'D:\Emulation\roms\gc';
const _wiiDir = r'D:\Emulation\roms\wii';
const _gcConsoleId = 16; // RC_CONSOLE_GAMECUBE
const _wiiConsoleId = 19; // RC_CONSOLE_WII
const _cisoBlockSize = 0x200000; // 2 MiB
const _maxPerFolder = 5; // each .rvz means multi-GB conversions; raise if needed

// Top-level finals are lazily initialised on first use.
final String _tmp = Directory.systemTemp.createTempSync('ravld_check').path;
final String _userDir = Directory('$_tmp/dolphin_user').path; // DolphinTool scratch

void main() => runApp(const _App());

Future<List<String>> _run() async {
  final out = <String>[];
  void log(String s) {
    out.add(s);
    debugPrint(s);
  }

  if (!File(_dolphinTool).existsSync()) {
    log('DolphinTool not found at:\n  $_dolphinTool');
    return out;
  }
  Directory(_userDir).createSync(recursive: true);
  log('DolphinTool: $_dolphinTool');

  for (final (dir, consoleId, name) in [
    (_gcDir, _gcConsoleId, 'GC'),
    (_wiiDir, _wiiConsoleId, 'Wii'),
  ]) {
    log('');
    final d = Directory(dir);
    if (!d.existsSync()) {
      log('[$name] missing folder: $dir');
      continue;
    }
    final rvzs = d
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.extension(f.path).toLowerCase() == '.rvz')
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    log('[$name] ${rvzs.length} .rvz found under $dir');
    for (final f in rvzs.take(_maxPerFolder)) {
      await _checkOne(f.path, consoleId, log);
    }
  }

  try {
    Directory(_tmp).deleteSync(recursive: true);
  } catch (_) {}
  log('');
  log('Done.');
  return out;
}

Future<void> _checkOne(
    String rvzPath, int consoleId, void Function(String) log) async {
  final name = p.basename(rvzPath);
  final iso = '$_tmp/ref.iso';
  final gcz = '$_tmp/real.gcz';
  final ciso = '$_tmp/repack.ciso';
  final wbfs = '$_tmp/repack.wbfs';

  try {
    log('....  $name — DolphinTool -> .iso …');
    if (!await _convert(rvzPath, iso, 'iso')) {
      log('SKIP  $name — DolphinTool could not make an ISO');
      return;
    }
    final reference = RawHash.hashFile(iso, consoleId);
    if (reference == null) {
      log('SKIP  $name — reference ISO did not hash');
      return;
    }
    log('      reference (iso) = $reference');

    // The real target: hash the .rvz itself through the on-device RvzReader.
    final rvzReader = openDiscReader(rvzPath);
    if (rvzReader == null) {
      log('N/A   RVZ  (native) — reader declined (unsupported compression, '
          'e.g. LZMA, or zstd-compressed Wii exception lists)');
    } else {
      String? v;
      try {
        v = RawHash.hashFileVirtual(rvzPath, rvzReader, consoleId);
      } finally {
        rvzReader.close();
      }
      if (v == reference) {
        log('PASS  RVZ  (native) $v');
      } else {
        log('FAIL  RVZ  (native) ref=$reference got=$v');
        _byteDiff(rvzPath, iso, log); // pinpoint the first divergence
      }
    }

    log('....  $name — DolphinTool -> .gcz …');
    if (await _convert(rvzPath, gcz, 'gcz')) {
      _compare('GCZ  (real) ', gcz, reference, consoleId, log);
    } else {
      log('----  GCZ  — DolphinTool could not make a GCZ');
    }

    log('....  $name — repacking .iso -> .ciso …');
    _writeCiso(iso, _cisoBlockSize, ciso);
    _compare('CISO (dart) ', ciso, reference, consoleId, log);

    log('....  $name — repacking .iso -> .wbfs …');
    _writeWbfs(iso, wbfs);
    _compare('WBFS (dart) ', wbfs, reference, consoleId, log);
  } catch (e) {
    log('ERROR $name — $e');
  } finally {
    for (final f in [iso, gcz, ciso, wbfs]) {
      try {
        File(f).deleteSync();
      } catch (_) {}
    }
  }
}

void _compare(String label, String container, String reference, int consoleId,
    void Function(String) log) {
  final reader = openDiscReader(container);
  if (reader == null) {
    log('FAIL  $label — openDiscReader rejected the container');
    return;
  }
  String? virtual;
  try {
    virtual = RawHash.hashFileVirtual(container, reader, consoleId);
  } finally {
    reader.close();
  }
  log(virtual == reference
      ? 'PASS  $label $virtual'
      : 'FAIL  $label ref=$reference got=$virtual');
}

// On a Wii RVZ mismatch, scan the reconstructed image against the DolphinTool
// ISO and report the first differing byte, so we know whether the bug is in the
// raw-data headers or the partition crypto and roughly which cluster.
void _byteDiff(String rvzPath, String isoPath, void Function(String) log) {
  final reader = openDiscReader(rvzPath);
  if (reader == null) return;
  final iso = File(isoPath).openSync();
  try {
    final total = reader.length;
    const step = 0x10000;
    const capBytes = 340 * 1024 * 1024; // reach into partition data
    final cap = total < capBytes ? total : capBytes;
    var diffs = 0;
    for (var off = 0; off < cap; off += step) {
      final n = (step < total - off) ? step : total - off;
      Uint8List mine;
      try {
        mine = reader.read(off, n);
      } catch (e) {
        log('      reader threw at disc 0x${off.toRadixString(16)}: $e');
        return;
      }
      iso.setPositionSync(off);
      final ref = iso.readSync(n);
      var lastReported = -1000;
      for (var i = 0; i < n; i++) {
        if (mine[i] != ref[i]) {
          final at = off + i;
          if (at - lastReported >= 16) {
            // Annotate position within a 0x8000 Wii cluster from 0x70000.
            final rel = at - 0x70000;
            final inCluster = rel >= 0 ? rel % 0x8000 : -1;
            final region = inCluster < 0
                ? 'raw'
                : (inCluster < 0x400 ? 'hash' : 'data');
            log('      diff 0x${at.toRadixString(16)} '
                '(cluster ${rel >= 0 ? rel ~/ 0x8000 : "-"} $region 0x${inCluster.toRadixString(16)}) '
                'mine=${mine[i].toRadixString(16)} iso=${ref[i].toRadixString(16)}');
            lastReported = at;
            if (++diffs >= 16) return;
          }
        }
      }
    }
    if (diffs == 0) log('      no diff in first ${cap ~/ (1024 * 1024)} MiB');
  } finally {
    reader.close();
    iso.closeSync();
  }
}

Future<bool> _convert(String input, String output, String format) async {
  final r = await Process.run(_dolphinTool, [
    'convert', '-u', _userDir, '-i', input, '-o', output, '-f', format,
  ]);
  return r.exitCode == 0 && File(output).existsSync();
}

// Repacks [isoPath] into a Dolphin-style CISO. All-zero blocks are marked absent
// (the reader returns zeros), so mostly-empty discs stay small.
void _writeCiso(String isoPath, int blockSize, String outPath) {
  final iso = File(isoPath).openSync();
  final out = File(outPath).openSync(mode: FileMode.write);
  try {
    final numBlocks = (iso.lengthSync() + blockSize - 1) ~/ blockSize;
    if (numBlocks > 32760) throw 'ISO too large for CISO block size';

    final header = Uint8List(0x8000);
    header.setAll(0, 'CISO'.codeUnits);
    ByteData.sublistView(header).setUint32(4, blockSize, Endian.little);
    out.writeFromSync(header); // placeholder; rewritten with the map below

    for (var i = 0; i < numBlocks; i++) {
      final chunk = iso.readSync(blockSize);
      if (chunk.every((b) => b == 0)) continue; // absent block
      header[8 + i] = 1;
      out.writeFromSync(chunk.length == blockSize
          ? chunk
          : (Uint8List(blockSize)..setAll(0, chunk)));
    }
    out.setPositionSync(0);
    out.writeFromSync(header);
  } finally {
    iso.closeSync();
    out.closeSync();
  }
}

// Repacks [isoPath] into a single-disc WBFS following Dolphin's layout: file
// sector 0 holds the header + wlba table; allocated logical sectors go to file
// sectors 1.. and the wlba table (big-endian u16) records where. Zero sectors
// are left unallocated (wlba 0), so the reader returns them as zeros.
void _writeWbfs(String isoPath, String outPath) {
  const hdShift = 9; // 512-byte hd sectors
  const wbfsShift = 21; // 2 MiB wbfs sectors
  const wiiSectorSize = 0x8000;
  const wiiSectorCount = 143432; // single-layer Wii disc
  final wbfsSec = 1 << wbfsShift;
  final hdSecSize = 1 << hdShift;
  final blocksPerDisc = (wiiSectorCount * wiiSectorSize + wbfsSec - 1) ~/ wbfsSec;

  final iso = File(isoPath).openSync();
  final out = File(outPath).openSync(mode: FileMode.write);
  try {
    final numLogical = (iso.lengthSync() + wbfsSec - 1) ~/ wbfsSec;
    if (numLogical > blocksPerDisc) throw 'ISO larger than a Wii disc';

    final wlba = ByteData(blocksPerDisc * 2); // big-endian u16, default 0
    final discHeader = Uint8List(256);
    var nextFree = 1; // file sector 0 is management

    for (var i = 0; i < numLogical; i++) {
      final chunk = iso.readSync(wbfsSec);
      if (i == 0) {
        discHeader.setAll(0, chunk.length < 256 ? chunk : chunk.sublist(0, 256));
      }
      if (chunk.every((b) => b == 0)) continue; // unallocated
      final fileIdx = nextFree++;
      wlba.setUint16(i * 2, fileIdx, Endian.big);
      out.setPositionSync(fileIdx * wbfsSec);
      out.writeFromSync(chunk.length == wbfsSec
          ? chunk
          : (Uint8List(wbfsSec)..setAll(0, chunk)));
    }

    final head = Uint8List(wbfsSec); // the whole first file sector
    head.setAll(0, 'WBFS'.codeUnits);
    ByteData.sublistView(head)
        .setUint32(4, (nextFree * wbfsSec) >> hdShift, Endian.big);
    head[8] = hdShift;
    head[9] = wbfsShift;
    head.setAll(hdSecSize, discHeader);
    head.setAll(hdSecSize + 256, wlba.buffer.asUint8List());
    out.setPositionSync(0);
    out.writeFromSync(head);
  } finally {
    iso.closeSync();
    out.closeSync();
  }
}

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  List<String> _lines = ['Running…'];

  @override
  void initState() {
    super.initState();
    _run().then((lines) {
      if (mounted) setState(() => _lines = lines);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _lines.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
