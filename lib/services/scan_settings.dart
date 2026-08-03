import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'console_map.dart';

/// Default extension allowlist (everything RA may recognise).
const kDefaultRomExtensions = <String>{
  'nes', 'snes', 'sfc', 'smc', 'gba', 'gbc', 'gb', 'n64', 'z64', 'v64',
  'nds', 'ndd', 'md', 'gen', 'smd', 'iso', 'bin', 'cue', 'img', 'chd',
  'psx', 'ps2', 'a26', 'a52', 'a78', 'lnx', 'ngp', 'ngc', 'gg', 'pce',
  'ccd', 'sub', 'fds', 'unf', 'unif', 'vb', 'vec', 'wsc', 'ws', 'dsk',
  'adf', 'rom', 'j64', 'jag', '32x', 'min', 'zip', '7z',
  // NKit uses `.nkit.iso`/`.nkit.gcm`, covered by 'iso'/'gcm'; no 'nkit' ext.
  'gcm', 'rvz', 'wbfs', 'wia', 'gcz', 'ciso',
  // Display-only consoles (no RA support): Switch, 3DS, Wii U, PS3/4/Vita, Xbox.
  'nsp', 'xci', 'nsz', 'xcz', // Switch
  '3ds', 'cia', 'cci', 'cxi', '3dsx', // 3DS
  'wux', 'wud', 'wua', 'rpx', // Wii U
  'pkg', 'vpk', // PS3/PS4, PS Vita (PS3/PS4 also 'iso'/'pkg')
  'xbe', 'xex', 'god', // Xbox / Xbox 360
};

/// Always unioned into saved lists so new formats reach users whose persisted
/// list would otherwise freeze to an old default. Not user-disableable;
/// switch to a one-time migration flag if that's ever needed.
const _alwaysScanExtensions = <String>{
  'gcm', 'rvz', 'wbfs', 'wia', 'gcz', 'ciso', 'min', '7z',
  // Display-only consoles; keep in sync with kDefaultRomExtensions above.
  'nsp', 'xci', 'nsz', 'xcz',
  '3ds', 'cia', 'cci', 'cxi', '3dsx',
  'wux', 'wud', 'wua', 'rpx',
  'pkg', 'vpk',
  'xbe', 'xex', 'god',
};

/// Bumped whenever a scan filter is saved. Screens that keep a cached copy
/// (Home, Storage) listen and re-read, so a Settings edit applies without a
/// restart: the shell's IndexedStack keeps them alive, so their initState
/// never runs again. The value is a change counter, not the filters.
final ValueNotifier<int> scanFiltersListenable = ValueNotifier(0);

const _extKey = 'enabled_extensions';
const _ignoredKey = 'ignored_folders';
const _consoleOverridesKey = 'folder_console_overrides';
const _excludedFilesKey = 'excluded_files';

/// The user's scan filters: extensions to hash, folder names to skip.
class ScanSettings {
  /// Tells the cached-filter screens (Home, Storage) to re-read.
  static void _publish() => scanFiltersListenable.value++;

  static Set<String> _parseExtensions(String raw) => raw
      .split(',')
      .map((e) => e.trim().replaceFirst('.', '').toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  static List<String> _parseNames(String raw) =>
      raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  /// Extensions to scan. Falls back to [kDefaultRomExtensions] when unset.
  static Future<Set<String>> enabledExtensions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_extKey);
    if (raw == null || raw.trim().isEmpty) return {...kDefaultRomExtensions};
    return {..._parseExtensions(raw), ..._alwaysScanExtensions};
  }

  static Future<void> setEnabledExtensions(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_extKey, _parseExtensions(raw).join(', '));
    _publish();
  }

  /// Raw text of the enabled extensions for editing in the UI.
  static Future<String> enabledExtensionsText() async {
    final set = await enabledExtensions();
    return set.join(', ');
  }

  /// Folder names (case preserved) the user wants the app to ignore.
  static Future<List<String>> ignoredFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return _parseNames(prefs.getString(_ignoredKey) ?? '');
  }

  static Future<void> setIgnoredFolders(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredKey, _parseNames(raw).join(', '));
    _publish();
  }

  /// Adds a single folder name to the ignore list (no-op if already present).
  static Future<void> addIgnoredFolder(String name) async {
    final current = await ignoredFolders();
    if (current.any((e) => e.toLowerCase() == name.toLowerCase())) return;
    current.add(name);
    await setIgnoredFolders(current.join(', '));
  }

  /// Drops a folder name from the ignore list (no-op if absent).
  static Future<void> removeIgnoredFolder(String name) async {
    final current = await ignoredFolders();
    final kept = current
        .where((e) => e.toLowerCase() != name.toLowerCase())
        .toList();
    if (kept.length == current.length) return;
    await setIgnoredFolders(kept.join(', '));
  }

  static Future<String> ignoredFoldersText() async {
    return (await ignoredFolders()).join(', ');
  }

  /// Folder-name -> console-id overrides; JSON so commas in names survive.
  static Future<Map<String, int>> folderConsoleOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_consoleOverridesKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Sets (or clears, when [consoleId] is null) the override for [folderName].
  static Future<void> setFolderConsoleOverride(
      String folderName, int? consoleId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await folderConsoleOverrides();
    if (consoleId == null) {
      current.remove(folderName);
    } else {
      current[folderName] = consoleId;
    }
    await prefs.setString(_consoleOverridesKey, jsonEncode(current));
  }

  /// Console id for a folder: override wins, else [ConsoleMap]; null unknown.
  static Future<int?> consoleIdForFolder(String folderName) async {
    final name = p.basename(folderName);
    final overrides = await folderConsoleOverrides();
    for (final entry in overrides.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return ConsoleMap.idForFolder(name);
  }

  /// Excluded ROM paths: hidden and skipped by scans, never deleted from disk.
  static Future<List<String>> excludedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_excludedFilesKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> setExcludedFiles(List<String> paths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_excludedFilesKey, jsonEncode(paths));
    _publish();
  }

  /// Adds [paths] to the excluded list (case-insensitive dedupe).
  static Future<void> addExcludedFiles(Iterable<String> paths) async {
    final current = await excludedFiles();
    final seen = current.map((e) => e.toLowerCase()).toSet();
    for (final path in paths) {
      if (seen.add(path.toLowerCase())) current.add(path);
    }
    await setExcludedFiles(current);
  }

  /// Removes [path] from the excluded list (case-insensitive). No-op if absent.
  static Future<void> removeExcludedFile(String path) async {
    final current = await excludedFiles();
    current.removeWhere((e) => e.toLowerCase() == path.toLowerCase());
    await setExcludedFiles(current);
  }

  /// The excluded paths as newline-separated text for the Settings field.
  static Future<String> excludedFilesText() async {
    return (await excludedFiles()).join('\n');
  }

  /// Parses [raw] (one path per line) and saves it as the excluded list.
  static Future<void> setExcludedFilesFromText(String raw) async {
    final paths = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await setExcludedFiles(paths);
  }

  /// True when [path] is excluded; separators normalised so \ and / compare equal.
  static bool isFileExcluded(String path, Set<String> excludedLower) {
    final normalised = path.toLowerCase().replaceAll('\\', '/');
    return excludedLower.any((e) => e.replaceAll('\\', '/') == normalised);
  }

  /// True when [path]'s extension is in the [enabled] allowlist.
  static bool hasEnabledExtension(String path, Set<String> enabled) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return enabled.contains(ext);
  }

  /// True when a folder's name matches one of [ignoredLower] (already lowercased).
  static bool isFolderIgnored(String folderPath, Set<String> ignoredLower) {
    return ignoredLower.contains(p.basename(folderPath).toLowerCase());
  }

  /// True when any directory segment of [path] *below* [root] matches an ignored
  /// folder name. Lets a recursive walk drop files inside a nested ignored
  /// folder without pruning the stream. Scoped to below [root] so an ignored
  /// name that happens to sit above the library root can't hide everything.
  /// Both separators accepted so it works the same on Windows and posix.
  static bool isUnderIgnoredFolder(
      String path, String root, Set<String> ignoredLower) {
    if (ignoredLower.isEmpty) return false;
    final pathSegs = _separatorSplit(path);
    final rootSegs = _separatorSplit(root);
    if (rootSegs.length >= pathSegs.length) return false;
    // Skip the last segment: it's the file name, not a folder.
    for (var i = rootSegs.length; i < pathSegs.length - 1; i++) {
      if (ignoredLower.contains(pathSegs[i].toLowerCase())) return true;
    }
    return false;
  }

  static List<String> _separatorSplit(String s) =>
      s.split(RegExp(r'[\\/]')).where((e) => e.isNotEmpty).toList();
}
