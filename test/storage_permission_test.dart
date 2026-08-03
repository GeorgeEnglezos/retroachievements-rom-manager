import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/storage_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('rarm/storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('hasAccess returns the channel value', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'hasAllFilesAccess');
      return true;
    });
    expect(await StoragePermission.hasAccess(), isTrue);
  });

  test('hasAccess defaults to false when channel returns null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await StoragePermission.hasAccess(), isFalse);
  });

  test('openSettings invokes openAllFilesAccessSettings', () async {
    String? invoked;
    messenger.setMockMethodCallHandler(channel, (call) async {
      invoked = call.method;
      return null;
    });
    await StoragePermission.openSettings();
    expect(invoked, 'openAllFilesAccessSettings');
  });
}
