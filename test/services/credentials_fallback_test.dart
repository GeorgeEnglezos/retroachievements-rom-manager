import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/credentials.dart';
import 'package:rarm/services/pref_keys.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Migration must not destroy the key on a Linux box with no keyring.
///
/// In fallback the "secure" store and the legacy pref are the same
/// SharedPreferences entry, so a naive write-then-remove would delete the value
/// it had just recovered. No mock platform is installed here, so every
/// flutter_secure_storage call throws and the fallback is active throughout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SecretStore.resetForTest());

  test('keeps the legacy key when there is no secure store', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.raApiKey: 'legacy-key'});

    expect(await readApiKey(), 'legacy-key');
    expect(SecretStore.usingFallback, isTrue);

    // Still readable on the next launch. A migration that removed the pref
    // here would have thrown the only copy away.
    expect(await readApiKey(), 'legacy-key');
  });

  test('save and read round-trip without a secure store', () async {
    SharedPreferences.setMockInitialValues({});

    await saveApiKey('typed-key');
    expect(await readApiKey(), 'typed-key');
  });

  test('clearing the key works without a secure store', () async {
    SharedPreferences.setMockInitialValues({});

    await saveApiKey('typed-key');
    await saveApiKey('');
    expect(await readApiKey(), '');
  });
}
