import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'disc_bytes_reader.dart';

export 'disc_bytes_reader.dart';

/// Dart API for the rcheevos-backed native hasher.
///
/// Bindings are hand-written (the surface is two functions). ffigen is not used
/// because it requires `libclang.dll`. The C surface lives in `src/raw_hash.h`.
class RawHash {
  RawHash._();

  static const String _libName = 'raw_hash';

  static final DynamicLibrary _dylib = () {
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('$_libName.framework/$_libName');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('lib$_libName.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('$_libName.dll');
    }
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }();

  // int raw_hash_file(char* out33, uint32_t console_id, const char* path)
  static final _rawHashFile = _dylib.lookupFunction<
      Int32 Function(Pointer<Uint8>, Uint32, Pointer<Utf8>),
      int Function(Pointer<Uint8>, int, Pointer<Utf8>)>('raw_hash_file');

  // void raw_hash_set_log_callback(void (*)(const char*))
  static final _rawHashSetLogCallback = _dylib.lookupFunction<
      Void Function(Pointer<NativeFunction<Void Function(Pointer<Utf8>)>>),
      void Function(
          Pointer<NativeFunction<Void Function(Pointer<Utf8>)>>)>(
    'raw_hash_set_log_callback',
  );

  // void raw_hash_set_filereader(open, seek, tell, read, close)
  static final _rawHashSetFilereader = _dylib.lookupFunction<
      Void Function(
          Pointer<NativeFunction<Pointer<Void> Function(Pointer<Utf8>)>>,
          Pointer<NativeFunction<Void Function(Pointer<Void>, Int64, Int32)>>,
          Pointer<NativeFunction<Int64 Function(Pointer<Void>)>>,
          Pointer<NativeFunction<Size Function(Pointer<Void>, Pointer<Void>, Size)>>,
          Pointer<NativeFunction<Void Function(Pointer<Void>)>>),
      void Function(
          Pointer<NativeFunction<Pointer<Void> Function(Pointer<Utf8>)>>,
          Pointer<NativeFunction<Void Function(Pointer<Void>, Int64, Int32)>>,
          Pointer<NativeFunction<Int64 Function(Pointer<Void>)>>,
          Pointer<NativeFunction<Size Function(Pointer<Void>, Pointer<Void>, Size)>>,
          Pointer<NativeFunction<Void Function(Pointer<Void>)>>)>(
    'raw_hash_set_filereader',
  );

  // int raw_hash_file_vreader(char* out33, uint32_t console_id, const char* path)
  static final _rawHashFileVreader = _dylib.lookupFunction<
      Int32 Function(Pointer<Uint8>, Uint32, Pointer<Utf8>),
      int Function(Pointer<Uint8>, int, Pointer<Utf8>)>('raw_hash_file_vreader');

  /// Computes the RetroAchievements hash for [path] using rcheevos.
  ///
  /// [consoleId] is an RA console id (disc systems require the correct id
  /// before hashing). `.chd` is handled via the bundled libchdr cdreader.
  /// Returns the 32-char lowercase hex hash, or `null` on failure.
  ///
  /// This is a blocking native call; run it off the UI isolate for large ROMs.
  static String? hashFile(String path, int consoleId) {
    final out = calloc<Uint8>(33);
    final pathPtr = path.toNativeUtf8();
    try {
      final ok = _rawHashFile(out, consoleId, pathPtr);
      if (ok == 0) return null;
      final hash = out.cast<Utf8>().toDartString();
      return hash.isEmpty ? null : hash;
    } finally {
      calloc.free(out);
      calloc.free(pathPtr);
    }
  }

  /// Computes the RA hash for a compressed disc container by streaming logical
  /// disc bytes from [reader] through rcheevos' virtual filereader, so the full
  /// `.iso` is never materialised. [path] is passed to rcheevos for the
  /// iterator only; the actual bytes come from [reader]. [consoleId] must be the
  /// GameCube/Wii RA console id. Returns the 32-char hex hash, or null.
  ///
  /// Blocking native call; run it off the UI isolate. The [reader] is used only
  /// for the duration of this call and is not closed here.
  static String? hashFileVirtual(
      String path, DiscBytesReader reader, int consoleId) {
    var pos = 0;

    final open =
        NativeCallable<Pointer<Void> Function(Pointer<Utf8>)>.isolateLocal(
            (Pointer<Utf8> _) => Pointer<Void>.fromAddress(1));
    final seek =
        NativeCallable<Void Function(Pointer<Void>, Int64, Int32)>.isolateLocal(
            (Pointer<Void> _, int offset, int origin) {
      pos = switch (origin) {
        0 => offset, // SEEK_SET
        1 => pos + offset, // SEEK_CUR
        2 => reader.length + offset, // SEEK_END
        _ => pos,
      };
    });
    final tell = NativeCallable<Int64 Function(Pointer<Void>)>.isolateLocal(
        (Pointer<Void> _) => pos,
        exceptionalReturn: 0);
    final read =
        NativeCallable<Size Function(Pointer<Void>, Pointer<Void>, Size)>
            .isolateLocal((Pointer<Void> _, Pointer<Void> buffer, int bytes) {
      final chunk = reader.read(pos, bytes);
      buffer.cast<Uint8>().asTypedList(chunk.length).setAll(0, chunk);
      pos += chunk.length;
      return chunk.length;
    }, exceptionalReturn: 0);
    final close = NativeCallable<Void Function(Pointer<Void>)>.isolateLocal(
        (Pointer<Void> _) {});

    final out = calloc<Uint8>(33);
    final pathPtr = path.toNativeUtf8();
    try {
      _rawHashSetFilereader(open.nativeFunction, seek.nativeFunction,
          tell.nativeFunction, read.nativeFunction, close.nativeFunction);
      final ok = _rawHashFileVreader(out, consoleId, pathPtr);
      if (ok == 0) return null;
      final hash = out.cast<Utf8>().toDartString();
      return hash.isEmpty ? null : hash;
    } finally {
      _rawHashSetFilereader(nullptr, nullptr, nullptr, nullptr, nullptr);
      open.close();
      seek.close();
      tell.close();
      read.close();
      close.close();
      calloc.free(out);
      calloc.free(pathPtr);
    }
  }

  /// Registers a native log callback for rcheevos verbose/error messages.
  ///
  /// The callback runs on the calling (native) thread. Use a `NativeCallable`
  /// when forwarding into Dart from a background isolate. Pass `nullptr` to clear.
  static void setLogCallback(
      Pointer<NativeFunction<Void Function(Pointer<Utf8>)>> callback) {
    _rawHashSetLogCallback(callback);
  }
}
