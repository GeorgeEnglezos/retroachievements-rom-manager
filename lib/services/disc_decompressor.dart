import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'emulator_store.dart';

/// Runs Dolphin's `DolphinTool` CLI to convert rvz/wbfs/... into a hashable
/// `.iso`. Desktop-only; every entry point degrades to null/false without it.
class DiscDecompressor {
  DiscDecompressor._();

  /// True on the desktop platforms where we can run a CLI subprocess.
  static bool get isSupportedPlatform =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Given a Dolphin executable path, returns the sibling `DolphinTool` path,
  /// or null if [dolphinExe] isn't a Dolphin build. Pure, no I/O.
  static String? toolPathNextTo(String dolphinExe) {
    final base = p.basenameWithoutExtension(dolphinExe).toLowerCase();
    if (base != 'dolphin' && base != 'dolphinqt') return null;
    final ext = Platform.isWindows ? '.exe' : '';
    return p.join(p.dirname(dolphinExe), 'DolphinTool$ext');
  }

  /// DolphinTool path from the configured Dolphin emulator, or null. Call on
  /// the main isolate (reads SharedPreferences).
  static Future<String?> resolveToolPath() async {
    if (!isSupportedPlatform) return null;
    for (final emu in await EmulatorStore.emulators()) {
      if (emu.kindId != 'dolphin') continue;
      final tool = toolPathNextTo(emu.exePath);
      if (tool != null && File(tool).existsSync()) return tool;
    }
    return null;
  }

  /// Decompresses [srcPath] to a temp `.iso` (caller deletes it); on failure
  /// `error` explains why. Panic dialogs are disabled and the process is
  /// killed after [timeout] so a malformed dump can't freeze the scan.
  static Future<({String? isoPath, String? error})> decompressToIso(
    String toolPath,
    String srcPath, {
    Duration timeout = const Duration(minutes: 15),
  }) async {
    final out = p.join(
      Directory.systemTemp.path,
      'ravld_${p.basenameWithoutExtension(srcPath)}_'
          '${DateTime.now().microsecondsSinceEpoch}.iso',
    );
    final proc = await Process.start(
      toolPath,
      ['convert', '-u', _panicFreeUserDir(), '-i', srcPath, '-o', out,
        '-f', 'iso'],
    );
    final err = StringBuffer();
    proc.stderr.transform(utf8.decoder).listen(err.write);
    proc.stdout.drain<void>();

    var timedOut = false;
    // Real conversions finish in under a minute; this only fires on a hang.
    final exitCode = await proc.exitCode.timeout(timeout, onTimeout: () {
      timedOut = true;
      proc.kill(ProcessSignal.sigkill);
      return -1;
    });

    if (exitCode != 0 || !File(out).existsSync()) {
      try {
        File(out).deleteSync();
      } catch (_) {}
      final stderr = err.toString().trim();
      return (
        isoPath: null,
        error: timedOut
            ? 'DolphinTool timed out after ${timeout.inMinutes} min'
            : (stderr.isEmpty ? 'DolphinTool exited with code $exitCode' : stderr),
      );
    }
    return (isoPath: out, error: null);
  }

  /// Private Dolphin user folder with panic dialogs off (`-u`), so failures
  /// return errors instead of a blocking message box.
  static String _panicFreeUserDir() {
    final dir = p.join(Directory.systemTemp.path, 'ravld_dolphin_user');
    final ini = File(p.join(dir, 'Config', 'Dolphin.ini'));
    if (!ini.existsSync()) {
      ini.parent.createSync(recursive: true);
      ini.writeAsStringSync('[Interface]\nUsePanicHandlers = False\n');
    }
    return dir;
  }
}
