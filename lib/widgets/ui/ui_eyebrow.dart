import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// A hero banner's kicker: an outlined pill rather than bare caps, so the label
/// keeps its own shape against whatever artwork sits behind it. Takes the fixed
/// kOnScrim* inks because it only ever sits on a scrim over art.
class UiEyebrow extends StatelessWidget {
  final String label;
  const UiEyebrow(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kOnScrim.withValues(alpha: 0.14),
          borderRadius: UiTokens.pill,
          border: Border.all(color: kOnScrim.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: context.ui.labelCaps
                .copyWith(color: kOnScrimAccent, fontSize: 10, letterSpacing: 2)),
      );
}
