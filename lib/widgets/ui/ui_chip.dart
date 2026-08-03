import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// GB DMG chip. Selected = red fill + beige text; unselected = card fill + ink
/// text. Hard ink border, no radius. A trailing ✕ appears when [onRemove] is
/// set (tapping it calls [onRemove], not [onTap]).
class UiChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const UiChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final fg = selected ? ui.background : ui.text;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 4, onRemove != null ? 4 : 8, 4),
        decoration: BoxDecoration(
          color: selected ? ui.accent : ui.surface,
          border: Border.all(color: ui.border, width: ui.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: ui.labelCaps.copyWith(color: fg, letterSpacing: 0.5)),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
