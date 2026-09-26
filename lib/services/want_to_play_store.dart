import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pref_keys.dart';

/// RA game ids from the last successful Want to Play sync. Pure cache of RA
/// state: read on every playlist refresh so the local playlist stays correct
/// between fetches, not just right after one; overwritten wholesale on the
/// next successful sync.
class WantToPlayStore {
  static Future<Set<int>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefKeys.raWantToPlayIds);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.raWantToPlayIds, jsonEncode(ids.toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.raWantToPlayIds);
  }
}
