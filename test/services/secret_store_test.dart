import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fallback path: a Linux desktop with no reachable secret service.
///
/// No mock platform is installed in this file, so flutter_secure_storage
/// resolves to its method-channel implementation and every call throws
/// MissingPluginException. That is exactly the failure this store has to
/// survive. The healthy path lives in secret_store_healthy_test.dart, in a
/// separate file because setMockInitialValues swaps a global with no way back.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecretStore.resetForTest();
  });

  test('falls back to prefs when the platform store throws', () async {
    await SecretStore.write('k', 'v');

    expect(await SecretStore.read('k'), 'v');
    expect(SecretStore.usingFallback, isTrue);

    // The fallback really is SharedPreferences, under the same key.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('k'), 'v');
  });

  test('delete removes the value on the fallback path', () async {
    await SecretStore.write('k', 'v');
    await SecretStore.delete('k');

    expect(await SecretStore.read('k'), isNull);
  });

  test('missing key reads as null', () async {
    expect(await SecretStore.read('never-set'), isNull);
    expect(SecretStore.usingFallback, isTrue);
  });

  test('a value written before failover is still found after it', () async {
    // Simulates the store working, then the keyring going away mid-session.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('k', 'written-earlier');

    expect(await SecretStore.read('k'), 'written-earlier');
  });
}
