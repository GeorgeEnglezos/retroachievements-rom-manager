import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// A status pill: fully rounded, color-coded fill at low opacity behind a
/// border in the same color.
class UiBadge extends StatelessWidget {
  final String label;
  final Color color;

  const UiBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: UiTokens.pill,
        border: Border.all(color: color, width: ui.borderWidth),
      ),
      child: Text(label, style: ui.labelCaps.copyWith(color: color, fontSize: 9)),
    );
  }
}
