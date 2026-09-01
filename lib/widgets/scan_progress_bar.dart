import 'package:flutter/material.dart';

import '../services/scan_progress.dart';
import '../theme/ui_tokens.dart';

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
        final ui = context.ui;
        return Material(
          color: ui.surface,
          shape: Border(
              top: BorderSide(color: ui.border, width: ui.borderWidth)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Not UiProgressBar: a live scan needs the
                      // indeterminate animation, and its entrance tween would
                      // fight the value updating every few frames.
                      LinearProgressIndicator(
                        value: p.value,
                        minHeight: 8,
                        color: ui.accent,
                        backgroundColor: ui.trough,
                        borderRadius: UiTokens.pill,
                      ),
                      if (p.label.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(p.label, style: ui.body),
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
