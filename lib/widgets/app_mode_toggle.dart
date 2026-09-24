import 'package:flutter/material.dart';
import '../services/app_mode.dart';
import 'ui/ui_focusable.dart';

/// What the two modes mean, shown next to [AppModeToggle] in Settings and the
/// setup wizard.
const kAppModeHelp =
    'Kiosk hides the maintenance tabs, scans, multi-select and every delete '
    'button, so the app is safe to hand over. A controller drives either mode.';

/// Cleaning / Kiosk switch bound to [appModeListenable].
class AppModeToggle extends StatelessWidget {
  const AppModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
      valueListenable: appModeListenable,
      builder: (context, mode, _) => UiFocusZoom(
        child: SegmentedButton<AppMode>(
          segments: const [
            ButtonSegment(value: AppMode.cleaning, label: Text('Cleaning')),
            ButtonSegment(value: AppMode.gaming, label: Text('Kiosk')),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => appModeListenable.save(s.first),
        ),
      ),
    );
  }
}
