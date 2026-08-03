import 'package:flutter/material.dart';
import '../../theme/ui_tokens.dart';

/// Retro progress bar: ink-bordered trough, red fill with 45-degree scanline
/// texture. [value] is 0..1.
class UiProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const UiProgressBar({super.key, required this.value, this.height = 14});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final clamped = value.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ui.trough,
        border: Border.all(color: ui.border, width: ui.borderWidth),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: c.maxWidth * clamped,
            child: CustomPaint(
              painter: _ScanlinePainter(fill: ui.accent, line: ui.background),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final Color fill;
  final Color line;
  _ScanlinePainter({required this.fill, required this.line});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final stroke = Paint()
      ..color = line.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    const gap = 6.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), stroke);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) =>
      old.fill != fill || old.line != line;
}
