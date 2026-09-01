import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/app_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appModeListenable.value = AppMode.cleaning;
  });
  tearDown(() => appModeListenable.value = AppMode.cleaning);

  test('defaults to cleaning with nothing stored', () async {
    expect(await loadAppMode(), AppMode.cleaning);
  });

  test('an unknown stored value falls back to cleaning', () async {
    SharedPreferences.setMockInitialValues({'app_mode': 'kiosk'});
    expect(await loadAppMode(), AppMode.cleaning);
  });

  test('save persists and publishes', () async {
    await saveAppMode(AppMode.gaming);
    expect(gamingMode, isTrue);
    expect(await loadAppMode(), AppMode.gaming);

    await saveAppMode(AppMode.cleaning);
    expect(gamingMode, isFalse);
    expect(await loadAppMode(), AppMode.cleaning);
  });

  test('init reads the stored mode', () async {
    SharedPreferences.setMockInitialValues({'app_mode': 'gaming'});
    await initAppMode();
    expect(appModeListenable.value, AppMode.gaming);
  });
}
