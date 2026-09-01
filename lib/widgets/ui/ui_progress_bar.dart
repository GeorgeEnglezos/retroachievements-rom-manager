import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Pill progress bar: ink trough, flat accent fill that animates in from the
/// left. [value] is 0..1; [color] defaults to the palette accent, [trough] to
/// the palette trough (override both when the bar sits on artwork/scrim, where
/// palette inks would be the wrong contrast).
class UiProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  final Color? trough;

  const UiProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.trough,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: UiTokens.pill,
      child: Container(
        height: height,
        color: trough ?? ui.trough,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutBack,
            builder: (context, t, _) => FractionallySizedBox(
              widthFactor: t.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color ?? ui.accent,
                  borderRadius: UiTokens.pill,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
