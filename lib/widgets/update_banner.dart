import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/file_actions.dart';
import '../services/update_check.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_badge.dart';
import 'ui/ui_button.dart';

/// Strip above the app body announcing a newer release. Dismissing it is the
/// caller's job (see [onDismiss]); this widget only reports the tap.
class UpdateBanner extends StatelessWidget {
  final ReleaseUpdate update;
  final VoidCallback onDismiss;

  const UpdateBanner(
      {super.key, required this.update, required this.onDismiss});

  // Below this the wording is dropped: the icon and version badge already say
  // "update", and a phone has no room for all of it.
  static const _compactWidth = 400.0;

  Future<void> _open(BuildContext context) async {
    if (await FileActions.openUrl(update.url) || !context.mounted) return;
    // No browser handler registered on this desktop. Hand over the address
    // rather than leaving a button that appears to do nothing.
    await Clipboard.setData(ClipboardData(text: update.url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Couldn't open your browser. The link is on your "
          'clipboard: ${update.url}'),
      duration: const Duration(seconds: 8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      color: ui.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      foregroundDecoration: BoxDecoration(
        border:
            Border(bottom: BorderSide(color: ui.border, width: ui.borderWidth)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _compactWidth;
          return Row(
            children: [
              Icon(Icons.system_update_alt, size: 18, color: ui.accent),
              const SizedBox(width: 10),
              // Expanded absorbs the slack so the actions stay right-aligned,
              // and lets the label ellipsize instead of overflowing.
              Expanded(
                child: Row(
                  children: [
                    if (!compact) ...[
                      Flexible(
                        child: Text('UPDATE AVAILABLE',
                            style: ui.labelCaps,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                    ],
                    UiBadge(label: 'v${update.version}', color: ui.accent),
                  ],
                ),
              ),
              UiButton(label: 'GET IT', onPressed: () => _open(context)),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                color: ui.muted,
                tooltip: 'Hide until the next release',
              ),
            ],
          );
        },
      ),
    );
  }
}
