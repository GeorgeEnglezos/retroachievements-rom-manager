import 'package:flutter/material.dart';

/// App-scoped scan progress so the loading bar can render above every route
/// (home, folder view, …) while a background sweep keeps running. The scan
/// itself still lives in HomeScreen; it just publishes progress here.
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

/// Persistent bottom bar showing the current sweep's progress + a cancel
/// button. Renders nothing when no scan is running. Mounted once above the
/// Navigator (see main.dart) so it survives route pushes like FolderView.
class ScanProgressBar extends StatelessWidget {
  const ScanProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ScanProgress.instance,
      builder: (context, _) {
        final p = ScanProgress.instance;
        if (!p.running) return const SizedBox.shrink();
        return Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: p.value),
                      if (p.label.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            p.label,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(p.cancelling ? 'Cancelling…' : 'Cancel'),
                  onPressed: p.cancelling ? null : p.requestCancel,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
