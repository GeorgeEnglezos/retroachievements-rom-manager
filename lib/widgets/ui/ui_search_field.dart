import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Rounded search text field with a clear (✕) button. The [controller] is
/// owned by the parent; this widget listens to it to show/hide the clear button.
class UiSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const UiSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<UiSearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<UiSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: context.ui.roundMd,
        borderSide: BorderSide(color: c, width: context.ui.borderWidth),
      );

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return TextField(
      controller: widget.controller,
      style: ui.body,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, color: ui.text),
        hintText: widget.hintText,
        filled: true,
        fillColor: ui.surface,
        border: _border(ui.border),
        enabledBorder: _border(ui.border),
        focusedBorder: _border(ui.accent),
        suffixIcon: widget.controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}
