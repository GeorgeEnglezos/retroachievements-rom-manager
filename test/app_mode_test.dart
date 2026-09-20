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
    await appModeListenable.init();
    expect(appModeListenable.value, AppMode.cleaning);
  });

  test('an unknown stored value falls back to cleaning', () async {
    SharedPreferences.setMockInitialValues({'app_mode': 'kiosk'});
    await appModeListenable.init();
    expect(appModeListenable.value, AppMode.cleaning);
  });

  test('save persists and publishes', () async {
    await appModeListenable.save(AppMode.gaming);
    expect(gamingMode, isTrue);
    // Forget the in-memory value, so init has to read it back off disk.
    appModeListenable.value = AppMode.cleaning;
    await appModeListenable.init();
    expect(appModeListenable.value, AppMode.gaming);

    await appModeListenable.save(AppMode.cleaning);
    expect(gamingMode, isFalse);
    appModeListenable.value = AppMode.gaming;
    await appModeListenable.init();
    expect(appModeListenable.value, AppMode.cleaning);
  });

  test('init reads the stored mode', () async {
    SharedPreferences.setMockInitialValues({'app_mode': 'gaming'});
    await appModeListenable.init();
    expect(appModeListenable.value, AppMode.gaming);
  });
}
