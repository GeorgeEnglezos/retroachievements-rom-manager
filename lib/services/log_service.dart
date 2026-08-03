import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });
}

/// Singleton logger: in-memory (live Logs tab) + per-session file.
/// Usage: LogService.info('Screen/method', 'message').
class LogService extends ChangeNotifier {
  LogService._();

  static final LogService _instance = LogService._();
  static LogService get instance => _instance;

  // Internal state

  static const int _maxEntries = 500;

  final List<LogEntry> _entries = [];
  File? _logFile;
  String? _logFolderPath;

  // Public static API

  /// Call once from main() before runApp(). [baseDir] overrides the app support
  /// directory for tests.
  static Future<void> init({Directory? baseDir}) async {
    final i = _instance;

    // Resolve the logs folder next to the app's support directory (alongside
    // the home index and per-system JSON kept under data/).
    final supportDir = baseDir ?? await getApplicationSupportDirectory();
    final logsDir = p.join(supportDir.path, 'logs');
    i._logFolderPath = logsDir;
    await Directory(logsDir).create(recursive: true);

    // Keep only the most recent session files.
    await i._rotate(logsDir);

    i._logFile = File(p.join(logsDir, _sessionFileName(DateTime.now())));
  }

  static List<LogEntry> get entries => List.unmodifiable(_instance._entries);

  static String? get logFolderPath => _instance._logFolderPath;

  static void debug(String source, String message) =>
      _instance._log(LogLevel.debug, source, message);

  static void info(String source, String message) =>
      _instance._log(LogLevel.info, source, message);

  static void warning(String source, String message) =>
      _instance._log(LogLevel.warning, source, message);

  static void error(String source, String message, {Object? err}) {
    final full = err != null ? '$message\n$err' : message;
    _instance._log(LogLevel.error, source, full);
  }

  static void clear() {
    _instance._entries.clear();
    _instance.notifyListeners();
  }

  // Internal helpers

  void _log(LogLevel level, String source, String message) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );

    if (_entries.length >= _maxEntries) _entries.removeAt(0);
    _entries.add(entry);

    _appendToFile(entry);

    // Framework errors (e.g. a layout overflow) are reported during the paint
    // phase and get logged here; notifying listeners synchronously would call
    // setState() mid-frame and throw. Defer to after the frame in that case.
    // In a background isolate (e.g. an Isolate.run import walk) there is no
    // binding, so guard the access; accessing it there throws "Binding has not
    // yet been initialized" and would crash the isolate.
    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } catch (_) {
      binding = null; // no Flutter binding on this isolate
    }
    if (binding == null) {
      notifyListeners();
    } else if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  String _format(LogEntry e) {
    final ts =
        e.timestamp.toIso8601String().replaceFirst('T', ' ').substring(0, 23);
    final level = e.level.name.toUpperCase().padRight(7);
    return '$ts [$level] ${e.source}: ${e.message}';
  }

  static String _sessionFileName(DateTime now) =>
      'session_${now.year.toString().padLeft(4, '0')}'
      '-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}'
      '_${now.hour.toString().padLeft(2, '0')}'
      '-${now.minute.toString().padLeft(2, '0')}'
      '-${now.second.toString().padLeft(2, '0')}.log';

  /// One synchronous append per line. An IOSink buffers, so a running session's
  /// log reads as empty on disk, exactly when a hung scan needs diagnosing, and
  /// flushing it per line throws "StreamSink is bound to a stream" on the next
  /// write, so each line opens, appends and closes the file on its own.
  void _appendToFile(LogEntry e) {
    final f = _logFile;
    if (f == null) return;
    try {
      f.writeAsStringSync('${_format(e)}\n', mode: FileMode.append);
    } catch (_) {
      // A log write must never take the app down.
    }
  }

  Future<void> _rotate(String logsDir) async {
    final dir = Directory(logsDir);
    if (!await dir.exists()) return;

    final files = await dir
        .list()
        .where((e) => e is File && p.basename(e.path).startsWith('session_'))
        .cast<File>()
        .toList();

    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    if (files.length >= 10) {
      for (final f in files.sublist(0, files.length - 9)) {
        await f.delete();
      }
    }
  }
}
