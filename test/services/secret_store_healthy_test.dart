import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The normal path: the platform store answers, so nothing touches prefs.
///
/// setMockInitialValues replaces FlutterSecureStoragePlatform.instance for the
/// whole process and offers no way to restore the throwing default, which is
/// why the fallback cases live in their own file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecretStore.resetForTest();
  });

  test('round-trips through the platform store, not prefs', () async {
    await SecretStore.write('k', 'v');

    expect(await SecretStore.read('k'), 'v');
    expect(SecretStore.usingFallback, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('k'), isNull);
  });

  test('delete removes the value', () async {
    await SecretStore.write('k', 'v');
    await SecretStore.delete('k');

    expect(await SecretStore.read('k'), isNull);
  });

  test('missing key reads as null', () async {
    expect(await SecretStore.read('never-set'), isNull);
  });
}
