import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

typedef UiDropdownItem<T> = ({T value, String label});

/// Dropdown: a button-styled trigger (current label + ▾) that opens a
/// PopupMenu of [items]. Dimmed and inert when [enabled] is false.
class UiDropdown<T> extends StatelessWidget {
  final T value;
  final List<UiDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const UiDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  String get _currentLabel =>
      items.firstWhere((i) => i.value == value, orElse: () => items.first).label;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PopupMenuButton<T>(
        enabled: enabled,
        position: PopupMenuPosition.under,
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final i in items)
            PopupMenuItem<T>(
              value: i.value,
              child: Text(i.label, style: ui.body),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ui.surface,
            borderRadius: ui.roundMd,
            border: Border.all(color: ui.border, width: ui.borderWidth),
            boxShadow: ui.shadow(ui.controlShadow),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentLabel, style: ui.labelCaps),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 18, color: ui.text),
            ],
          ),
        ),
      ),
    );
  }
}
