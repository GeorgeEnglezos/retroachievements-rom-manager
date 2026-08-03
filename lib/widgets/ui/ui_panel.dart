import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Dark ink panel (used for "session log" / readout areas). Text on it should
/// use light colors.
class UiPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const UiPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ui.text,
        border: Border.all(color: ui.border, width: ui.borderWidth),
        boxShadow: ui.shadow(),
      ),
      child: DefaultTextStyle(
        style: ui.mono.copyWith(color: ui.background, fontSize: 11),
        child: child,
      ),
    );
  }
}
