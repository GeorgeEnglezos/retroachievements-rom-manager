import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';
import 'ui_focusable.dart';

enum UiButtonVariant { primary, secondary }

/// Rounded button: accent fill (primary) or surface fill (secondary) behind a
/// hairline border, plus the press translate + drop shadow when the palette
/// sets a non-zero [UiTokens.controlShadow].
class UiButton extends StatefulWidget {
  final String label;
  final IconData? icon;

  /// Optional leading widget (e.g. an avatar); shown before the label. With an
  /// empty label the button renders just this widget.
  final Widget? leading;
  final VoidCallback? onPressed;
  final UiButtonVariant variant;

  const UiButton({
    super.key,
    this.label = '',
    this.icon,
    this.leading,
    this.onPressed,
    this.variant = UiButtonVariant.primary,
  });

  @override
  State<UiButton> createState() => _ButtonState();
}

class _ButtonState extends State<UiButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final enabled = widget.onPressed != null;
    final primary = widget.variant == UiButtonVariant.primary;
    final bg = !enabled
        ? ui.trough
        : primary
        ? ui.accent
        : ui.surface;
    final fg = primary && enabled ? ui.background : ui.text;
    final pressed = _pressed && enabled;

    return UiFocusable(
      onPressed: widget.onPressed,
      borderRadius: ui.roundMd,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          transform: Matrix4.translationValues(
            pressed ? ui.controlShadow.dx : 0,
            pressed ? ui.controlShadow.dy : 0,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: ui.roundMd,
            border: Border.all(color: ui.border, width: ui.borderWidth),
            boxShadow: pressed ? const [] : ui.shadow(ui.controlShadow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                if (widget.label.isNotEmpty) const SizedBox(width: 8),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              if (widget.label.isNotEmpty)
                Text(widget.label, style: ui.labelCaps.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
