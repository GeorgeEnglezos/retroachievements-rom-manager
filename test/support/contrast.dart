import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// WCAG 2.1 contrast maths, used to keep both palettes legible.
///
/// A semi-transparent foreground is composited over its ground before the
/// ratio is taken, so tokens that ship with alpha (dark's hairline border and
/// its muted ink) are measured the way they actually render.

double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

Color _flatten(Color fg, Color bg) => Color.fromARGB(
      255,
      ((fg.r * fg.a + bg.r * (1 - fg.a)) * 255).round(),
      ((fg.g * fg.a + bg.g * (1 - fg.a)) * 255).round(),
      ((fg.b * fg.a + bg.b * (1 - fg.a)) * 255).round(),
    );

/// Contrast ratio of [fg] over [bg]: 1.0 when identical, 21.0 for black on
/// white. [bg] is assumed opaque.
double contrastRatio(Color fg, Color bg) {
  final a = _luminance(_flatten(fg, bg));
  final b = _luminance(bg);
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}
