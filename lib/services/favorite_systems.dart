import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'favorite_systems';

/// Systems the user pinned to the top of the Library grid.
///
/// Keyed by folder name (lower-cased basename) rather than full path, like the
/// ignore list and the console overrides, so moving the library root keeps the
/// favorites. A combined console group counts as favorite when any of its
/// folders is.
class FavoriteSystems {
  static Future<Set<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Adds or removes [folderPath]'s folder name; returns the new set.
  static Future<Set<String>> toggle(String folderPath) async {
    final name = _name(folderPath);
    final current = await all();
    if (!current.remove(name)) current.add(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current.toList()));
    return current;
  }

  static bool isFavorite(Set<String> favorites, Iterable<String> folderPaths) =>
      folderPaths.any((path) => favorites.contains(_name(path)));

  static String _name(String folderPath) =>
      p.basename(folderPath).toLowerCase();
}
