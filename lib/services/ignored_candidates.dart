import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pref_keys.dart';

/// Games dismissed from Home's mastery/beat spotlight banners, keyed by
/// [memberKeyFor] (see member_key.dart). [buildHomeDashboard] skips a
/// dismissed game when picking those two heroes and promotes the next
/// candidate instead.
class IgnoredCandidates {
  IgnoredCandidates._();
  static final IgnoredCandidates instance = IgnoredCandidates._();

  Set<String>? _mem;

  @visibleForTesting
  void resetForTest() => _mem = null;

  Future<Set<String>> load() async {
    final mem = _mem;
    if (mem != null) return mem;
    final prefs = await SharedPreferences.getInstance();
    return _mem =
        (prefs.getStringList(PrefKeys.homeIgnoredSpotlights) ?? const [])
            .toSet();
  }

  Future<void> ignore(String key) async {
    final set = await load();
    if (!set.add(key)) return;
    await _persist(set);
  }

  Future<void> unignore(String key) async {
    final set = await load();
    if (!set.remove(key)) return;
    await _persist(set);
  }

  Future<void> _persist(Set<String> set) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(PrefKeys.homeIgnoredSpotlights, set.toList());
  }
}
