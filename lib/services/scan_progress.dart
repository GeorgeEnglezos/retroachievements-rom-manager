import 'package:flutter/foundation.dart';

/// App-scoped scan progress so the loading bar can render above every route
/// (home, folder view, …) while a background sweep keeps running. Runs publish
/// here through ScanRun; the bar widget only listens.
class ScanProgress extends ChangeNotifier {
  static final ScanProgress instance = ScanProgress._();
  ScanProgress._();

  bool running = false;
  bool cancelling = false;
  double? value; // null => indeterminate
  String label = '';
  VoidCallback? onCancel;

  void publish({
    required bool running,
    double? value,
    String label = '',
    VoidCallback? onCancel,
  }) {
    if (!this.running && running) cancelling = false; // a new run starts clean
    this.running = running;
    this.value = value;
    this.label = label;
    this.onCancel = onCancel;
    notifyListeners();
  }

  /// Fires [onCancel] once and latches the bar into its cancelling state, so
  /// repeat presses do nothing and the label shows the press landed. The sweep
  /// still finishes the ROM it is on before it stops.
  void requestCancel() {
    if (cancelling || onCancel == null) return;
    cancelling = true;
    notifyListeners();
    onCancel!();
  }

  void stop() {
    running = false;
    cancelling = false;
    value = null;
    label = '';
    onCancel = null;
    notifyListeners();
  }
}
