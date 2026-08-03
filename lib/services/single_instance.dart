import 'dart:io';

/// Enforces a single running desktop instance.
///
/// Desktop OSes happily launch a second copy of the app; mobile OSes reuse the
/// existing task, so enforcement only applies to Windows/Linux/macOS. We claim
/// a fixed loopback port: the first instance binds it and holds it for its
/// lifetime; a second instance fails to bind and knows to bail out.
///
/// The second instance just exits; it does not raise or focus the first
/// window, which would need per-platform native window code.
class SingleInstance {
  SingleInstance._();

  /// Arbitrary high port unlikely to collide with a real service.
  static const int _port = 51820;

  static ServerSocket? _lock;

  /// Returns true if this process may run: it either acquired the lock or the
  /// platform doesn't need one. False means another instance already holds it
  /// and the caller should exit. [port] is injectable so tests don't collide
  /// with a running app on the real port.
  static Future<bool> acquire({int port = _port}) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return true;
    }
    try {
      _lock = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      return true;
    } on SocketException {
      return false;
    }
  }

  /// Releases the lock. Only needed by tests, a real instance holds it until
  /// the process dies.
  static Future<void> release() async {
    await _lock?.close();
    _lock = null;
  }
}
