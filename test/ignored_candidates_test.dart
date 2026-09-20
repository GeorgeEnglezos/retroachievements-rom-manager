import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/ignored_candidates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IgnoredCandidates.instance.clear();
  });

  test('a fresh store has no ignored keys', () async {
    expect(await IgnoredCandidates.instance.load(), isEmpty);
  });

  test('ignore adds the key and persists it across loads', () async {
    await IgnoredCandidates.instance.ignore('ra:1');
    IgnoredCandidates.instance.clear();
    expect(await IgnoredCandidates.instance.load(), {'ra:1'});
  });

  test('unignore removes a previously ignored key', () async {
    await IgnoredCandidates.instance.ignore('ra:1');
    await IgnoredCandidates.instance.unignore('ra:1');
    IgnoredCandidates.instance.clear();
    expect(await IgnoredCandidates.instance.load(), isEmpty);
  });
}
