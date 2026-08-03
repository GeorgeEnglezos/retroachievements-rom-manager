import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

typedef UiSegment<T> = ({T value, String label, IconData? icon});

/// GB DMG segmented control. The selected segment is ink-filled; the rest are
/// card-filled. Segments are divided by ink rules. When [enabled] is false the
/// whole control is dimmed and ignores taps.
class UiSegmented<T> extends StatelessWidget {
  final T value;
  final List<UiSegment<T>> segments;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const UiSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ui.border, width: ui.borderWidth),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                Container(width: ui.borderWidth, height: 24, color: ui.border),
              GestureDetector(
                onTap: enabled ? () => onChanged(segments[i].value) : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: segments[i].value == value ? ui.text : ui.surface,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (segments[i].icon != null)
                        Icon(segments[i].icon,
                            size: 14,
                            color: segments[i].value == value
                                ? ui.background
                                : ui.text),
                      if (segments[i].icon != null && segments[i].label.isNotEmpty)
                        const SizedBox(width: 4),
                      if (segments[i].label.isNotEmpty)
                        Text(
                          segments[i].label,
                          style: ui.labelCaps.copyWith(
                            color: segments[i].value == value
                                ? ui.background
                                : ui.text,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
