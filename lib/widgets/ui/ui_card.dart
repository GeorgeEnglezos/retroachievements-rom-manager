import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// White surface with the signature ink border. Both palettes currently use a
/// zero shadow offset, so the press feedback (translate + drop shadow) only
/// shows if a palette sets a non-zero [UiTokens.cardShadow] again.
class UiCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const UiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  State<UiCard> createState() => _CardState();
}

class _CardState extends State<UiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final pressed = _pressed && widget.onTap != null;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      transform: Matrix4.translationValues(
        pressed ? ui.cardShadow.dx : 0,
        pressed ? ui.cardShadow.dy : 0,
        0,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? ui.surface,
        border: Border.all(
            color: widget.borderColor ?? ui.border, width: ui.borderWidth),
        boxShadow: pressed ? const [] : ui.shadow(),
      ),
      child: widget.child,
    );
    if (widget.onTap == null) return body;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: body,
    );
  }
}
