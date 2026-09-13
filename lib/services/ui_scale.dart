import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The zoom levels the picker offers, smallest first. 1.0 is the size every
/// layout was designed at; the rest divide the viewport so the app still
/// reflows instead of just cropping.
const uiScaleSteps = <double>[0.75, 0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

const _uiScaleKey = 'ui_scale';

/// Live zoom factor, shared across screens. Settings and the setup wizard
/// write it; [UiZoom] rebuilds the app from it so a change applies immediately.
final ValueNotifier<double> uiScaleListenable = ValueNotifier(1.0);

double _clamp(double scale) =>
    scale.clamp(uiScaleSteps.first, uiScaleSteps.last);

/// Loads the saved zoom, defaulting to 100%.
Future<double> loadUiScale() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getDouble(_uiScaleKey);
  return stored == null ? 1.0 : _clamp(stored);
}

/// Reads the saved zoom into [uiScaleListenable]. Call once at startup.
Future<void> initUiScale() async {
  uiScaleListenable.value = await loadUiScale();
}

/// Persists the chosen zoom and publishes it to listeners.
Future<void> saveUiScale(double scale) async {
  final clamped = _clamp(scale);
  uiScaleListenable.value = clamped;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_uiScaleKey, clamped);
}

/// The step [delta] notches away from [scale], stopping at the ends. A value
/// that is not one of [uiScaleSteps] (an older build's pref) snaps to the
/// nearest step first, so +/- still moves by one visible notch.
double uiScaleStep(double scale, int delta) {
  var i = uiScaleSteps.indexOf(scale);
  if (i < 0) {
    i = 0;
    for (var j = 1; j < uiScaleSteps.length; j++) {
      if ((uiScaleSteps[j] - scale).abs() < (uiScaleSteps[i] - scale).abs()) {
        i = j;
      }
    }
  }
  return uiScaleSteps[(i + delta).clamp(0, uiScaleSteps.length - 1)];
}

/// The zoom as the picker shows it, e.g. `125%`.
String uiScaleLabel(double scale) => '${(scale * 100).round()}%';
