import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'log_service.dart';

/// File-system and shell actions for a single ROM, plus pure URL builders.
/// Side-effecting methods work on Windows, macOS, and Linux, never throw to
/// the UI, and return false on failure (after logging).
class FileActions {
  FileActions._();

  /// RetroAchievements game page for [gameId].
  static String raGameUrl(int gameId) =>
      'https://retroachievements.org/game/$gameId';

  /// Supported-games list for a console; full game list when unknown.
  static String raSupportedListUrl(int? consoleId) => consoleId == null
      ? 'https://retroachievements.org/gameList.php'
      : 'https://retroachievements.org/system/$consoleId/games';

  /// Google search from the file stem (minus (...)/[...]) + parent folder.
  static String googleSearchUrl(String filePath) {
    final stem = p.basenameWithoutExtension(filePath);
    final folder = p.basename(p.dirname(filePath));
    final clean = stem
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .trim();
    final query = '$clean $folder'.trim();
    return 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
  }

  /// Reveals [path] in the file manager, selected where the OS supports it
  /// (Linux can only open the containing folder).
  static Future<bool> revealInExplorer(String path) async {
    try {
      if (Platform.isWindows) {
        // Dart's arg quoting produces "/select,path", which explorer's custom
        // parser rejects. PowerShell's --% passes /select,"path" verbatim.
        final winPath = path.replaceAll('/', '\\');
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          '& explorer.exe --% /select,"$winPath"',
        ]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [p.dirname(path)]);
        return true;
      }
      LogService.error('FileActions/revealInExplorer',
          'Unsupported platform: ${Platform.operatingSystem}');
      return false;
    } catch (e) {
      LogService.error('FileActions/revealInExplorer', 'Failed for $path', err: e);
      return false;
    }
  }

  /// Moves the file to the platform trash. True only when the file is gone.
  static Future<bool> moveToRecycleBin(String path) async {
    try {
      if (Platform.isAndroid) {
        // Android apps have no user-facing trash; hard-delete the raw path
        // (we hold MANAGE_EXTERNAL_STORAGE, so this works). Ground truth is
        // the file being gone; an already-absent file is success.
        if (File(path).existsSync()) await File(path).delete();
        return !File(path).existsSync();
      }
      ProcessResult result;
      if (Platform.isWindows) {
        // Double single-quotes to escape them inside the PowerShell string.
        final escaped = path.replaceAll("'", "''");
        final script =
            "Add-Type -AssemblyName Microsoft.VisualBasic; "
            "[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile("
            "'$escaped','OnlyErrorDialogs','SendToRecycleBin')";
        result = await Process.run(
            'powershell', ['-NoProfile', '-Command', script]);
      } else if (Platform.isMacOS) {
        // POSIX path -> Finder alias; backslash/quote escaped for AppleScript.
        final escaped = path.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        final script =
            'tell application "Finder" to delete (POSIX file "$escaped" as alias)';
        result = await Process.run('osascript', ['-e', script]);
      } else if (Platform.isLinux) {
        result = await Process.run('gio', ['trash', '--', path]);
      } else {
        LogService.error('FileActions/moveToRecycleBin',
            'Unsupported platform: ${Platform.operatingSystem}');
        return false;
      }
      // Ground truth is the file being gone, not the exit code; an
      // already-absent file is success, not failure.
      if (!File(path).existsSync()) return true;
      LogService.error('FileActions/moveToRecycleBin',
          'exit=${result.exitCode} for $path: ${result.stderr}');
      return false;
    } catch (e) {
      LogService.error('FileActions/moveToRecycleBin', 'Failed for $path', err: e);
      return false;
    }
  }

  /// Opens [path] with the OS default handler for its file type.
  static Future<bool> launchWithDefaultApp(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
      LogService.error('FileActions/launchWithDefaultApp',
          'Unsupported platform: ${Platform.operatingSystem}');
      return false;
    } catch (e) {
      LogService.error(
          'FileActions/launchWithDefaultApp', 'Failed for $path', err: e);
      return false;
    }
  }

  /// Quote-aware split of a launch command into `[program, ...args]`.
  /// Returns [] on an unterminated quote so a typo'd template fails loudly.
  static List<String> tokenizeCommand(String command) {
    final tokens = <String>[];
    final buf = StringBuffer();
    String? quote;
    var inToken = false;
    for (var i = 0; i < command.length; i++) {
      final c = command[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else {
          buf.write(c);
        }
      } else if (c == '"' || c == "'") {
        quote = c;
        inToken = true;
      } else if (c == ' ' || c == '\t') {
        if (inToken) {
          tokens.add(buf.toString());
          buf.clear();
          inToken = false;
        }
      } else {
        buf.write(c);
        inToken = true;
      }
    }
    if (quote != null) return [];
    if (inToken) tokens.add(buf.toString());
    return tokens;
  }

  /// Fills {file.path}/{file.dir} into [template] (template does the quoting),
  /// tokenizes, and launches detached so the emulator survives this app closing.
  // Literal " in a path breaks tokenizing (illegal on Windows, not handled).
  // macOS .app bundles are dirs Process.start can't exec; revisit if supported.
  static Future<bool> launchWithTemplate(String template, String romPath) async {
    try {
      final filled = template
          .replaceAll('{file.path}', romPath)
          .replaceAll('{file.dir}', p.dirname(romPath));
      final tokens = tokenizeCommand(filled);
      if (tokens.isEmpty) {
        LogService.error('FileActions/launchWithTemplate',
            'Empty command from template: $template');
        return false;
      }
      // Run from the emulator's folder; many resolve config/cores relative
      // to the working directory.
      final program = tokens.first;
      final workdir = p.isAbsolute(program) ? p.dirname(program) : null;
      if (Platform.isWindows && isConsoleExe(program)) {
        return await _startWithConsole(program, tokens.sublist(1), workdir);
      }
      await Process.start(program, tokens.sublist(1),
          mode: ProcessStartMode.detached, workingDirectory: workdir);
      return true;
    } catch (e) {
      LogService.error(
          'FileActions/launchWithTemplate', 'Failed for $romPath', err: e);
      return false;
    }
  }

  /// Windows: launches a console-subsystem program detached but *with* a
  /// console. [ProcessStartMode.detached] gives the child no console at all,
  /// which kills such a program during runtime startup, before it can log a
  /// word (Ryujinx is one; every GUI emulator is unaffected). `start` hands it
  /// its own console and still detaches. The empty argument is the window
  /// title, which `start` otherwise takes from the first quoted argument.
  // ponytail: cmd re-parses what Dart passes it, so an argument holding `&`
  // with no spaces (Dart only quotes when spaces are present) would split the
  // command. Pass the tokens through environment variables, as
  // [resolveShortcuts] does, if a ROM name ever trips it.
  static Future<bool> _startWithConsole(
      String program, List<String> args, String? workdir) async {
    // `start` reports a missing program in its own dialog and still exits 0,
    // so the caller would never see the failure. Check it here instead.
    if (!File(program).existsSync()) {
      LogService.error(
          'FileActions/launchWithTemplate', 'Emulator not found: $program');
      return false;
    }
    await Process.start(
        'cmd',
        [
          '/c', 'start', '',
          if (workdir != null) ...['/d', workdir],
          program,
          ...args,
        ],
        mode: ProcessStartMode.detached);
    return true;
  }

  /// Whether [exePath] is a Windows console-subsystem program, read from the
  /// PE header's Subsystem field (2 = GUI, 3 = console). False for anything
  /// that isn't a readable PE file, so an odd path takes the normal path.
  static bool isConsoleExe(String exePath) {
    RandomAccessFile? file;
    try {
      file = File(exePath).openSync();
      final dos = file.readSync(0x40);
      // 'MZ', then the PE header offset at 0x3c.
      if (dos.length < 0x40 || dos[0] != 0x4D || dos[1] != 0x5A) return false;
      final peOffset = ByteData.sublistView(dos).getUint32(0x3c, Endian.little);
      file.setPositionSync(peOffset);
      // 'PE  ' + 20-byte COFF header, then Subsystem 0x44 into the optional
      // header; same offset for PE32 and PE32+.
      final header = file.readSync(0x5e);
      if (header.length < 0x5e) return false;
      return ByteData.sublistView(header).getUint16(0x5c, Endian.little) == 3;
    } catch (_) {
      return false;
    } finally {
      try {
        file?.closeSync();
      } catch (_) {}
    }
  }

  /// Creates a Desktop .lnk launching [targetPath] with [arguments].
  /// Windows-only; returns the shortcut path, or null on failure/other OS.
  static Future<String?> createEmulatorShortcut({
    required String shortcutName,
    required String targetPath,
    required String arguments,
    String? workingDir,
    String? iconPath,
  }) async {
    if (!Platform.isWindows) {
      LogService.error('FileActions/createEmulatorShortcut',
          'Shortcuts are Windows-only (${Platform.operatingSystem})');
      return null;
    }
    try {
      final safeName =
          shortcutName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final desktop = p.join(
          Platform.environment['USERPROFILE'] ?? '', 'Desktop');
      final lnkPath = p.join(desktop, '$safeName.lnk');
      final wd = workingDir ?? p.dirname(targetPath);
      String q(String s) => "'${s.replaceAll("'", "''")}'";
      final script = StringBuffer()
        ..writeln(r'$ws = New-Object -ComObject WScript.Shell')
        ..writeln('\$s = \$ws.CreateShortcut(${q(lnkPath)})')
        ..writeln('\$s.TargetPath = ${q(targetPath)}')
        ..writeln('\$s.Arguments = ${q(arguments)}')
        ..writeln('\$s.WorkingDirectory = ${q(wd)}')
        ..writeln('\$s.IconLocation = ${q(iconPath ?? targetPath)}')
        ..writeln(r'$s.Save()');
      final result = await Process.run(
          'powershell', ['-NoProfile', '-Command', script.toString()]);
      if (result.exitCode == 0 && File(lnkPath).existsSync()) return lnkPath;
      LogService.error('FileActions/createEmulatorShortcut',
          'exit=${result.exitCode}: ${result.stderr}');
      return null;
    } catch (e) {
      LogService.error('FileActions/createEmulatorShortcut',
          'Failed for $shortcutName', err: e);
      return null;
    }
  }

  /// Resolves Windows `.lnk` shortcuts to their target paths in one shell call.
  /// Returns a map of input path -> TargetPath; a shortcut that won't resolve is
  /// simply absent. Empty off Windows or when [lnkPaths] is empty.
  static Future<Map<String, String>> resolveShortcuts(
      List<String> lnkPaths) async {
    if (!Platform.isWindows || lnkPaths.isEmpty) return {};
    File? listFile;
    try {
      // Pass the paths via a temp file (one per line) so arbitrary path chars
      // never have to survive PowerShell -Command quoting.
      listFile = File(p.join(Directory.systemTemp.path,
          'rarm_lnk_${DateTime.now().microsecondsSinceEpoch}.txt'));
      await listFile.writeAsString(lnkPaths.join('\n'));
      const script = r'''
$ws = New-Object -ComObject WScript.Shell
Get-Content -LiteralPath $env:RARM_LNK_LIST | ForEach-Object {
  if ($_ -ne '') { try { $ws.CreateShortcut($_).TargetPath } catch { '' } }
}''';
      final result = await Process.run(
          'powershell', ['-NoProfile', '-Command', script],
          environment: {'RARM_LNK_LIST': listFile.path});
      if (result.exitCode != 0) {
        LogService.error('FileActions/resolveShortcuts',
            'exit=${result.exitCode}: ${result.stderr}');
        return {};
      }
      // One output line per input, in order; blank when it didn't resolve.
      final targets = (result.stdout as String).split(RegExp(r'\r?\n'));
      final out = <String, String>{};
      for (var i = 0; i < lnkPaths.length && i < targets.length; i++) {
        final t = targets[i].trim();
        if (t.isNotEmpty) out[lnkPaths[i]] = t;
      }
      return out;
    } catch (e) {
      LogService.error('FileActions/resolveShortcuts', 'Failed', err: e);
      return {};
    } finally {
      try {
        listFile?.deleteSync();
      } catch (_) {}
    }
  }

  /// Opens a URL in the default browser. Returns false on failure.
  static Future<bool> openUrl(String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        LogService.error('FileActions/openUrl', 'launchUrl returned false for $url');
      }
      return ok;
    } catch (e) {
      LogService.error('FileActions/openUrl', 'Failed for $url', err: e);
      return false;
    }
  }
}
