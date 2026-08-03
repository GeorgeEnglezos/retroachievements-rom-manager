import 'package:flutter/services.dart';

/// Android 11+ "All files access" gate (method channel). Callers guard with
/// `Platform.isAndroid`.
class StoragePermission {
  StoragePermission._();

  static const _channel = MethodChannel('rarm/storage');

  /// Whether the app currently has all-files access (always true pre-Android 11,
  /// which relies on legacy external storage).
  static Future<bool> hasAccess() async =>
      await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;

  /// Opens the system "All files access" settings page for this app. Returns
  /// immediately; the user grants it there and retries the action.
  static Future<void> openSettings() =>
      _channel.invokeMethod<void>('openAllFilesAccessSettings');
}
