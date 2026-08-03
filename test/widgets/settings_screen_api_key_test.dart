import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/screens/settings_screen.dart';
import 'package:rarm/services/credentials.dart';
import 'package:rarm/services/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    SecretStore.resetForTest();
  });

  testWidgets('the API key is not saved until the field loses focus',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('settings-apikey'));
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'ABC123');
    await tester.pump();

    // Still typing: an encrypted write per keystroke is what this avoids.
    expect(await readApiKey(), '');

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(await readApiKey(), 'ABC123');
  });

  testWidgets('a saved key is loaded back into the field', (tester) async {
    await saveApiKey('SAVED99');

    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('settings-apikey')),
    );
    expect(field.controller?.text, 'SAVED99');
  });
}
