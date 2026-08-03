import 'scan_progress.dart';

/// One fetch run's progress and cancel state. Publishes to [ScanProgress] so
/// the app-wide bar renders it on any route, and exposes [cancelled] for
/// FetchEngine's isCancelled hook. The home sweep and the folder view share
/// this one contract, so both get a labelled bar and a working Cancel button.
class ScanRun {
  /// Items ticked off so far.
  int done = 0;

  /// Expected item count. Zero means indeterminate.
  int total = 0;

  String _label = '';
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  /// True while any run holds the (singleton) bar. Entry points disable on
  /// this so two runs cannot write the same SystemData at once.
  static bool get busy => ScanProgress.instance.running;

  void start({int total = 0, String label = ''}) {
    done = 0;
    this.total = total;
    _label = label;
    _cancelled = false;
    _publish();
  }

  /// Adds to the denominator. Callers that count their work folder by folder
  /// use this instead of knowing the whole total up front.
  void addTotal(int count) {
    total += count;
    _publish();
  }

  void tick({String? label}) {
    done++;
    if (label != null) _label = label;
    _publish();
  }

  /// Changes the label without advancing, e.g. when a new folder starts.
  void relabel(String label) {
    _label = label;
    _publish();
  }

  void stop() => ScanProgress.instance.stop();

  void _publish() => ScanProgress.instance.publish(
        running: true,
        value: total == 0 ? null : done / total,
        label: _label,
        onCancel: () => _cancelled = true,
      );
}
