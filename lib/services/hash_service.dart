import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:raw_hash/raw_hash.dart';

import 'disc_decompressor.dart';
import 'disc_formats.dart';
import 'disc_reader.dart';

// Extensions that can live inside a zip and be hashed by rcheevos.
const _romExtensions = {
  'nes', 'snes', 'sfc', 'smc', 'gba', 'gbc', 'gb', 'n64', 'z64', 'v64',
  'nds', 'ndd', 'md', 'gen', 'smd', 'iso', 'bin', 'img', 'chd',
  'a26', 'a52', 'a78', 'lnx', 'ngp', 'ngc', 'gg', 'pce',
  'fds', 'unf', 'unif', 'vb', 'vec', 'wsc', 'ws', 'rom', 'j64', 'jag', '32x',
  'min',
};

// Arcade ROMs are identified by the archive's filename, never unpacked.
const _arcadeConsoleId = 27;

class HashService {
  /// Computes the RA hash via rcheevos on a background isolate. Cartridge
  /// zips are unpacked first (rcheevos can't hash those containers).
  /// Returns the hex hash (null on failure), rcheevos' diagnostic [log], and a
  /// human-readable [note] set when the on-device reader was bypassed for the
  /// DolphinTool fallback (so the caller can surface it in the logs).
  static Future<
      ({
        String? hash,
        List<String> log,
        bool unsupportedFormat,
        String? note
      })> computeHash(String filePath, int consoleId, {String? dolphinToolPath}) {
    return Isolate.run(() => _hash(filePath, consoleId, dolphinToolPath));
  }

  static Future<
      ({
        String? hash,
        List<String> log,
        bool unsupportedFormat,
        String? note
      })> _hash(String filePath, int consoleId, String? dolphinToolPath) async {
    // NKit can't be hashed even via DolphinTool (output stays NKit, RA
    // returns GameID 0); the real fix is converting to ISO/RVZ.
    if (DiscFormats.isNkit(filePath)) {
      return (
        hash: null,
        log: const <String>[],
        unsupportedFormat: true,
        note: null
      );
    }

    // rcheevos can't hash a 7z container and we don't unpack them (scanned for
    // display-only libraries); hashing the raw archive would yield a garbage
    // hash and a false "no match".
    if (p.extension(filePath).toLowerCase() == '.7z') {
      return (
        hash: null,
        log: const <String>[],
        unsupportedFormat: true,
        note: null
      );
    }

    final log = <String>[];

    // On-device readers (CISO/WBFS/GCZ always; RVZ for GameCube). These hash
    // with no DolphinTool, so they work on Android too. Opening the reader is
    // pure Dart file I/O — no native call until we actually hash.
    if (DiscFormats.hasOnDeviceReader(filePath)) {
      final reader = openDiscReader(filePath);
      if (reader != null) {
        try {
          final hash = _runNative(
              log, () => RawHash.hashFileVirtual(filePath, reader, consoleId));
          return (hash: hash, log: log, unsupportedFormat: false, note: null);
        } finally {
          reader.close();
        }
      }
      // Reader declined (Wii RVZ / unsupported compression): fall back to
      // DolphinTool if present, otherwise it's unsupported here.
      if (!DiscFormats.needsDolphinTool(filePath) || dolphinToolPath == null) {
        return (hash: null, log: log, unsupportedFormat: true, note: null);
      }
    } else if (DiscFormats.needsDolphinTool(filePath) &&
        dolphinToolPath == null) {
      // WIA, no tool.
      return (hash: null, log: log, unsupportedFormat: true, note: null);
    }

    if (DiscFormats.needsDolphinTool(filePath)) {
      final note = DiscFormats.hasOnDeviceReader(filePath)
          ? 'on-device RVZ reader declined (unsupported compression); '
              'used DolphinTool'
          : 'no on-device reader for this format; used DolphinTool';
      final result =
          await DiscDecompressor.decompressToIso(dolphinToolPath!, filePath);
      if (result.isoPath == null) {
        log.add('DolphinTool failed to decompress $filePath'
            '${result.error == null || result.error!.isEmpty ? '' : ': ${result.error}'}');
        return (hash: null, log: log, unsupportedFormat: false, note: note);
      }
      final iso = result.isoPath!;
      try {
        final hash = _runNative(log, () => RawHash.hashFile(iso, consoleId));
        return (hash: hash, log: log, unsupportedFormat: false, note: note);
      } finally {
        try {
          File(iso).deleteSync();
        } catch (_) {}
      }
    }

    final hash = _runNative(
        log,
        () => shouldUnzip(filePath, consoleId)
            ? _hashZip(filePath, consoleId)
            : RawHash.hashFile(filePath, consoleId));
    return (hash: hash, log: log, unsupportedFormat: false, note: null);
  }

  /// Runs [hashFn] with the rcheevos log callback wired into [log]. The callback
  /// is process-global and only safe while hashing is sequential (FetchEngine
  /// hashes one file at a time); concurrent hashing needs a thread-local shim.
  static String? _runNative(List<String> log, String? Function() hashFn) {
    final cb = NativeCallable<Void Function(Pointer<Utf8>)>.isolateLocal(
      (Pointer<Utf8> msg) => log.add(msg.toDartString()),
    );
    try {
      RawHash.setLogCallback(cb.nativeFunction);
      return hashFn();
    } finally {
      RawHash.setLogCallback(nullptr);
      cb.close();
    }
  }

  /// Whether to unpack as a zip before hashing. Arcade zips must NOT be
  /// unpacked; rcheevos hashes the archive filename itself.
  static bool shouldUnzip(String filePath, int consoleId) =>
      consoleId != _arcadeConsoleId &&
      p.extension(filePath).toLowerCase() == '.zip';

  static String? _hashZip(String zipPath, int consoleId) {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final ext = p.extension(entry.name).toLowerCase().replaceFirst('.', '');
      if (!_romExtensions.contains(ext)) continue;

      // Temp file keeps the extension; rcheevos picks the algorithm from it.
      final tmp = p.join(
        Directory.systemTemp.path,
        'ravld_${DateTime.now().microsecondsSinceEpoch}_'
            '${entry.name.replaceAll(RegExp(r'[/\\]'), '_')}',
      );
      try {
        File(tmp).writeAsBytesSync(entry.content as List<int>);
        return RawHash.hashFile(tmp, consoleId);
      } finally {
        try {
          File(tmp).deleteSync();
        } catch (_) {}
      }
    }
    return null; // no recognisable ROM found inside the zip
  }
}
