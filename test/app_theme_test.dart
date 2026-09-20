import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => appThemeListenable.value = AppTheme.dark);

  test('defaults to dark when nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    await appThemeListenable.init();
    expect(appThemeListenable.value, AppTheme.dark);
  });

  test('an unrecognised stored value falls back to dark', () async {
    // Guards the persisted contract: a theme removed in a later build must not
    // crash an old pref, it degrades to the default.
    SharedPreferences.setMockInitialValues({'app_theme': 'bogus'});
    await appThemeListenable.init();
    expect(appThemeListenable.value, AppTheme.dark);
  });

  test('every theme round-trips through prefs by name', () async {
    // The enum .name is the on-disk key; this catches a rename that would
    // silently reset a user's saved theme.
    for (final theme in AppTheme.values) {
      SharedPreferences.setMockInitialValues({});
      await appThemeListenable.save(theme);
      expect(appThemeListenable.value, theme);
      // Forget it, then read it back off disk.
      appThemeListenable.value = AppTheme.dark;
      await appThemeListenable.init();
      expect(appThemeListenable.value, theme);
    }
  });

  test('theme labels are unique', () {
    final labels = AppTheme.values.map((t) => t.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
  });
}
