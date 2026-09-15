import 'package:flutter/material.dart';

/// Shows a popup menu anchored at [position] (a right-click or long-press's
/// global offset), the app's shared right-click/long-press interaction.
/// Returns the chosen value, or null if dismissed without a choice.
Future<T?> showPositionedMenu<T>(
  BuildContext context,
  Offset position,
  List<PopupMenuEntry<T>> items,
) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(40, 40),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
}
