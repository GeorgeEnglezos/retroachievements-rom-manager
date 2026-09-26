import 'package:flutter/material.dart';
import '../services/app_mode.dart';
import '../strings.dart';
import 'ui/ui_focusable.dart';

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
            ButtonSegment(value: AppMode.cleaning, label: Text(AppearanceStrings.modeCleaning)),
            ButtonSegment(value: AppMode.gaming, label: Text(AppearanceStrings.modeKiosk)),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) => appModeListenable.save(s.first),
        ),
      ),
    );
  }
}
