import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One enum-valued setting: the live value screens listen to, plus its load and
/// save. Persisted by [Enum.name], so reordering the enum can't reinterpret a
/// stored value and an unrecognised one degrades to [fallback] rather than
/// throwing. Being a [ValueNotifier] is what lets settings_bus.dart merge it.
class EnumSetting<T extends Enum> extends ValueNotifier<T> {
  EnumSetting(this._key, this._values, this._fallback) : super(_fallback);

  final String _key;
  final List<T> _values;
  final T _fallback;

  /// Reads the stored value into this notifier. Call once at startup, so the
  /// first build uses the saved value.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    value = _values.asNameMap()[prefs.getString(_key)] ?? _fallback;
  }

  /// Publishes [next] to listeners, then persists it.
  Future<void> save(T next) async {
    value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.name);
  }
}
