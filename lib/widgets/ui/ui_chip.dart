import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'ui_focusable.dart';

/// Pill chip. Selected = accent fill + background-colored text; unselected =
/// surface fill + normal ink. A trailing ✕ appears when [onRemove] is set
/// (tapping it calls [onRemove], not [onTap]).
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
    // Only a tappable chip is focusable; a plain display tag (onTap null) stays
    // out of the d-pad path.
    return UiFocusable(
      onPressed: onTap,
      borderRadius: UiTokens.pill,
      flourish: FocusFlourish.none,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(10, 4, onRemove != null ? 6 : 10, 4),
          decoration: BoxDecoration(
            color: selected ? ui.accent : ui.surface,
            borderRadius: UiTokens.pill,
            border: Border.all(color: ui.border, width: ui.borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: ui.labelCaps.copyWith(color: fg, letterSpacing: 0.5),
              ),
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
      ),
    );
  }
}
