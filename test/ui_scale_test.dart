import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/ui_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    uiScaleListenable.value = 1.0;
  });

  test('defaults to 100% when nothing saved', () async {
    expect(await loadUiScale(), 1.0);
  });

  test('a stored value outside the offered range is clamped', () async {
    // Guards the persisted contract: a hand-edited or retired pref must not
    // zoom the app to an unusable size.
    SharedPreferences.setMockInitialValues({'ui_scale': 12.0});
    expect(await loadUiScale(), uiScaleSteps.last);
    SharedPreferences.setMockInitialValues({'ui_scale': 0.01});
    expect(await loadUiScale(), uiScaleSteps.first);
  });

  test('every step round-trips through prefs', () async {
    for (final step in uiScaleSteps) {
      SharedPreferences.setMockInitialValues({});
      await saveUiScale(step);
      expect(uiScaleListenable.value, step);
      expect(await loadUiScale(), step);
    }
  });

  test('stepping moves one notch and stops at the ends', () {
    expect(uiScaleStep(uiScaleSteps[1], 1), uiScaleSteps[2]);
    expect(uiScaleStep(uiScaleSteps[1], -1), uiScaleSteps[0]);
    expect(uiScaleStep(uiScaleSteps.first, -1), uiScaleSteps.first);
    expect(uiScaleStep(uiScaleSteps.last, 1), uiScaleSteps.last);
  });

  test('stepping from an off-grid value snaps to the nearest step', () {
    // An older build could have saved a value no longer offered; +/- must
    // still move somewhere sensible instead of jumping to the smallest step.
    final between = (uiScaleSteps[1] + uiScaleSteps[2]) / 2 + 0.001;
    expect(uiScaleStep(between, 1), uiScaleSteps[3]);
  });

  test('label reads as a percentage', () {
    expect(uiScaleLabel(1.0), '100%');
    expect(uiScaleLabel(1.25), '125%');
  });
}
