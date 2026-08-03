import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted key/value storage: Keystore on Android, DPAPI on Windows,
/// libsecret on Linux.
///
/// A Linux desktop with no running secret service (a minimal WM, or a Flatpak
/// sandbox that was never granted the secrets portal) makes every call throw.
/// Rather than block sign-in there, the first failure flips this store over to
/// SharedPreferences for the rest of the process. Those machines are no worse
/// off than before this store existed, and nobody hits a wall.
///
/// The fallback writes under the same key, so a value stored before the
/// failover is still found after it.
abstract final class SecretStore {
  // Defaults are the maintained ciphers on every platform. Don't set
  // AndroidOptions.encryptedSharedPreferences: it is deprecated as of v10,
  // which moved off the discontinued Jetpack Crypto library.
  static const _storage = FlutterSecureStorage();

  static bool _fellBack = false;

  /// True once a platform call has failed and this store switched to prefs.
  /// Only meaningful after at least one read or write.
  static bool get usingFallback => _fellBack;

  static Future<String?> read(String key) async {
    if (!_fellBack) {
      try {
        return await _storage.read(key: key);
      } catch (_) {
        _fellBack = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> write(String key, String value) async {
    if (!_fellBack) {
      try {
        await _storage.write(key: key, value: value);
        return;
      } catch (_) {
        _fellBack = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<void> delete(String key) async {
    if (!_fellBack) {
      try {
        await _storage.delete(key: key);
        return;
      } catch (_) {
        _fellBack = true;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Clears the sticky fallback flag so each test starts from a known state.
  /// Tests only. Not annotated @visibleForTesting because that would pull in
  /// `meta` as a direct dependency for one annotation.
  static void resetForTest() => _fellBack = false;
}
