import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/app_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to dark when nothing saved', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadAppTheme(), AppTheme.dark);
  });

  test('saveAppTheme persists and publishes', () async {
    SharedPreferences.setMockInitialValues({});
    // Saves the non-default, so a no-op save would fail this.
    await saveAppTheme(AppTheme.light);
    expect(appThemeListenable.value, AppTheme.light);
    expect(await loadAppTheme(), AppTheme.light);
  });

  test('paletteFor maps enum to UiTokens palette', () {
    expect(paletteFor(AppTheme.light), UiTokens.light);
    expect(paletteFor(AppTheme.dark), UiTokens.dark);
  });
}
