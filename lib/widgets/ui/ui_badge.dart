import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// A status pill: ink border, no radius, color-coded fill at low opacity.
class UiBadge extends StatelessWidget {
  final String label;
  final Color color;

  const UiBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: ui.borderWidth),
      ),
      child: Text(label, style: ui.labelCaps.copyWith(color: color, fontSize: 9)),
    );
  }
}
