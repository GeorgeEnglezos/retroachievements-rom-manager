import 'package:flutter/material.dart';
import '../services/ui_scale.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_button.dart';

/// A minus / percentage / plus stepper that zooms the whole app. Used by both
/// Settings and the setup wizard; it writes [saveUiScale], and the live app
/// rebuilds from [uiScaleListenable] itself.
class UiScaleControl extends StatelessWidget {
  const UiScaleControl({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return ValueListenableBuilder<double>(
      valueListenable: uiScaleListenable,
      builder: (context, scale, _) {
        final atMin = scale <= uiScaleSteps.first;
        final atMax = scale >= uiScaleSteps.last;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UiButton(
              icon: Icons.remove,
              variant: UiButtonVariant.secondary,
              onPressed: atMin ? null : () => saveUiScale(uiScaleStep(scale, -1)),
            ),
            SizedBox(
              width: 72,
              child: Text(
                uiScaleLabel(scale),
                textAlign: TextAlign.center,
                style: ui.display.copyWith(fontSize: 17),
              ),
            ),
            UiButton(
              icon: Icons.add,
              variant: UiButtonVariant.secondary,
              onPressed: atMax ? null : () => saveUiScale(uiScaleStep(scale, 1)),
            ),
          ],
        );
      },
    );
  }
}
