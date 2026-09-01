import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'emulator_catalog.dart';

/// A user-added emulator: a program plus which catalog kind it is.
class Emulator {
  final String id;
  final String name;
  final String exePath;
  final String kindId;
  final String extraArgs;

  Emulator({
    required this.id,
    required this.name,
    required this.exePath,
    required this.kindId,
    this.extraArgs = '',
  });

  Emulator copyWith({String? exePath, String? extraArgs}) => Emulator(
        id: id,
        name: name,
        exePath: exePath ?? this.exePath,
        kindId: kindId,
        extraArgs: extraArgs ?? this.extraArgs,
      );

  factory Emulator.fromJson(Map<String, dynamic> j) => Emulator(
        id: j['id'] as String,
        name: j['name'] as String,
        exePath: j['exePath'] as String,
        kindId: j['kindId'] as String,
        extraArgs: j['extraArgs'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exePath': exePath,
        'kindId': kindId,
        'extraArgs': extraArgs,
      };
}

/// A console's link to an emulator plus the args to launch its ROMs with.
class EmulatorConnection {
  final String emulatorId;
  final String args; // contains {file.path}

  EmulatorConnection({required this.emulatorId, required this.args});

  factory EmulatorConnection.fromJson(Map<String, dynamic> j) =>
      EmulatorConnection(
          emulatorId: j['emulatorId'] as String, args: j['args'] as String);

  Map<String, dynamic> toJson() => {'emulatorId': emulatorId, 'args': args};
}

/// Persists emulators and per-console connections, and builds the launch
/// command for a console. Storage is JSON in SharedPreferences.
class EmulatorStore {
  EmulatorStore._();

  static const _emulatorsKey = 'emulators';
  // Stores EmulatorConnection records (console -> emulator+args), not emulators;
  // named distinctly from the retired 'console_emulators' key to avoid confusion.
  static const _connectionsKey = 'console_connections';
  static const _fullscreenKey = 'launch_fullscreen';
  // Set once the Android installed-app sweep has run, so removing an
  // auto-detected emulator sticks instead of coming back on the next visit.
  static const _androidSweptKey = 'android_emulators_swept';

  static Future<List<Emulator>> emulators() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_emulatorsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Emulator.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveEmulators(List<Emulator> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _emulatorsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<Map<int, EmulatorConnection>> connections() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_connectionsKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(
          int.parse(k),
          EmulatorConnection.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveConnections(
      Map<int, EmulatorConnection> conns) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _connectionsKey,
        jsonEncode(
            conns.map((k, v) => MapEntry(k.toString(), v.toJson()))));
  }

  /// Adds [emu] and auto-connects its default consoles (never overwrites).
  // Read-modify-write isn't atomic; fine for sequential button taps.
  static Future<void> addEmulator(Emulator emu) async {
    final list = await emulators();
    list.removeWhere((e) => e.id == emu.id);
    list.add(emu);
    await _saveEmulators(list);
    await _autoConnect(emu);
  }

  /// Repoints emulator [id] at [newExePath]; catalog-default connections
  /// follow the move, hand-edited ones are untouched.
  static Future<void> updateEmulatorExe(String id, String newExePath) async {
    final list = await emulators();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final old = list[idx];
    final updated = old.copyWith(exePath: newExePath);
    list[idx] = updated;
    await _saveEmulators(list);

    final conns = await connections();
    var changed = false;
    for (final consoleId in conns.keys.toList()) {
      final c = conns[consoleId]!;
      if (c.emulatorId != id) continue;
      final oldDefault =
          EmulatorCatalog.defaultArgsFor(consoleId, old.kindId, old.exePath);
      if (oldDefault == null || c.args != oldDefault) continue; // custom: keep
      final newDefault = EmulatorCatalog.defaultArgsFor(
          consoleId, updated.kindId, newExePath);
      if (newDefault == null) continue;
      conns[consoleId] = EmulatorConnection(emulatorId: id, args: newDefault);
      changed = true;
    }
    if (changed) await _saveConnections(conns);
  }

  /// Removes the emulator with [id] and any connections pointing at it.
  static Future<void> removeEmulator(String id) async {
    final list = await emulators()..removeWhere((e) => e.id == id);
    await _saveEmulators(list);
    final conns = await connections()
      ..removeWhere((_, c) => c.emulatorId == id);
    await _saveConnections(conns);
  }

  static Future<void> setConnection(
      int consoleId, String emulatorId, String args) async {
    final conns = await connections();
    conns[consoleId] = EmulatorConnection(emulatorId: emulatorId, args: args);
    await _saveConnections(conns);
  }

  static Future<void> clearConnection(int consoleId) async {
    final conns = await connections()..remove(consoleId);
    await _saveConnections(conns);
  }

  /// Whether games launch fullscreen (applies the per-kind flag). Default true.
  static Future<bool> launchFullscreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_fullscreenKey) ?? true;
  }

  static Future<void> setLaunchFullscreen(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_fullscreenKey, value);
  }

  /// Whether the one-time Android sweep of installed emulator apps has run.
  /// Returns false and marks it done, so callers auto-detect exactly once.
  static Future<bool> takeAndroidSweep() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_androidSweptKey) ?? false) return false;
    await prefs.setBool(_androidSweptKey, true);
    return true;
  }

  /// Updates the [extraArgs] of emulator [id] in place (no connection changes).
  static Future<void> setExtraArgs(String id, String extraArgs) async {
    final list = await emulators();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    list[idx] = list[idx].copyWith(extraArgs: extraArgs);
    await _saveEmulators(list);
  }

  static Future<void> _autoConnect(Emulator emu) async {
    final conns = await connections();
    for (final consoleId in EmulatorCatalog.consolesForKind(emu.kindId)) {
      if (conns.containsKey(consoleId)) continue;
      final args =
          EmulatorCatalog.defaultArgsFor(consoleId, emu.kindId, emu.exePath);
      if (args == null) continue;
      conns[consoleId] =
          EmulatorConnection(emulatorId: emu.id, args: args);
    }
    await _saveConnections(conns);
  }

  /// The emulator connected to [consoleId], or null when none is set or it no
  /// longer exists. On Android its [Emulator.exePath] is the app package name.
  static Future<Emulator?> connectedEmulator(int consoleId) async {
    final conn = (await connections())[consoleId];
    if (conn == null) return null;
    return (await emulators())
        .where((e) => e.id == conn.emulatorId)
        .firstOrNull;
  }

  /// Launch command template for [consoleId]: the quoted exe, then the
  /// fullscreen flag and extra args (if any), then the per-console args, still
  /// containing {file.path}. Null when the console has no connection or its
  /// emulator no longer exists. Feed to FileActions.launchWithTemplate.
  static Future<String?> commandFor(int consoleId) async {
    final conn = (await connections())[consoleId];
    if (conn == null) return null;
    final emu = await connectedEmulator(consoleId);
    if (emu == null) return null;

    final parts = <String>['"${emu.exePath}"'];
    if (await launchFullscreen()) {
      final flag = EmulatorCatalog.fullscreenFlag(emu.kindId);
      if (flag != null) parts.add(flag);
    }
    if (emu.extraArgs.trim().isNotEmpty) parts.add(emu.extraArgs.trim());
    parts.add(conn.args);
    return parts.join(' ');
  }
}
