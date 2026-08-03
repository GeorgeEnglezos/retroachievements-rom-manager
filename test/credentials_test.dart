import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/credentials.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SecretStore.resetForTest();
  });

  test('returns saved (username, apiKey)', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.raUsername: 'user'});
    await saveApiKey('key');

    expect(await savedCredentials(), ('user', 'key'));
  });

  test('null when either half is missing', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.raUsername: 'user'});
    expect(await savedCredentials(), isNull);

    SharedPreferences.setMockInitialValues({});
    await saveApiKey('key');
    expect(await savedCredentials(), isNull);
  });

  test('migrates a legacy plaintext pref into secure storage', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.raApiKey: 'legacy-key'});

    expect(await readApiKey(), 'legacy-key');

    expect(await SecretStore.read(PrefKeys.raApiKey), 'legacy-key');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raApiKey), isNull,
        reason: 'the plaintext copy must be gone after migration');
  });

  test('migration does not resurrect the pref on a second read', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.raApiKey: 'legacy-key'});

    await readApiKey();
    expect(await readApiKey(), 'legacy-key');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PrefKeys.raApiKey), isNull);
  });

  test('saving an empty key clears it', () async {
    SharedPreferences.setMockInitialValues({});
    await saveApiKey('key');
    await saveApiKey('');

    expect(await readApiKey(), '');
  });

  test('unset key reads as empty string', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await readApiKey(), '');
  });
}
