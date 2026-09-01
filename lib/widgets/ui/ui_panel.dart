import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Inset readout panel (used for "session log" areas): the trough color, one
/// step darker than the surrounding surface, with mono text in normal ink.
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
        color: ui.trough,
        borderRadius: ui.roundLg,
        border: Border.all(color: ui.border, width: ui.borderWidth),
        boxShadow: ui.shadow(),
      ),
      child: DefaultTextStyle(
        style: ui.mono.copyWith(fontSize: 11),
        child: child,
      ),
    );
  }
}
