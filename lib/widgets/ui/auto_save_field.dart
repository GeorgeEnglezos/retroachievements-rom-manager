import 'package:flutter/material.dart';
import 'ui_focusable.dart';

/// Text field that saves on blur/enter and reseeds when [value] changes
/// (state is reused across reloads when the parent keys it).
class AutoSaveTextField extends StatefulWidget {
  final String value;
  final String label;
  final ValueChanged<String> onSave;

  const AutoSaveTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onSave,
  });

  @override
  State<AutoSaveTextField> createState() => _AutoSaveTextFieldState();
}

class _AutoSaveTextFieldState extends State<AutoSaveTextField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode()..addListener(_onBlur);

  void _onBlur() {
    if (!_focus.hasFocus) widget.onSave(_ctrl.text);
  }

  @override
  void didUpdateWidget(AutoSaveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never clobber in-progress typing; reseed only while unfocused.
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onBlur);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UiFocusZoom(
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
        ),
        onEditingComplete: () => widget.onSave(_ctrl.text),
      ),
    );
  }
}
