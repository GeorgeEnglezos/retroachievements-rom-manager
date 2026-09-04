import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to dark when nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadAppTheme(), AppTheme.dark);
  });

  test('an unrecognised stored value falls back to dark', () async {
    // Guards the persisted contract: a theme removed in a later build must not
    // crash an old pref, it degrades to the default.
    SharedPreferences.setMockInitialValues({'app_theme': 'bogus'});
    expect(await loadAppTheme(), AppTheme.dark);
  });

  test('every theme round-trips through prefs by name', () async {
    // The enum .name is the on-disk key; this catches a rename that would
    // silently reset a user's saved theme.
    for (final theme in AppTheme.values) {
      SharedPreferences.setMockInitialValues({});
      await saveAppTheme(theme);
      expect(appThemeListenable.value, theme);
      expect(await loadAppTheme(), theme);
    }
  });

  test('theme labels are unique', () {
    final labels = AppTheme.values.map((t) => t.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
  });
}
