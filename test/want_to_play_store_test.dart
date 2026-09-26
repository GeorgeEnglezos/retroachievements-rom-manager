import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/want_to_play_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('read is empty before any write', () async {
    expect(await WantToPlayStore.read(), isEmpty);
  });

  test('write then read round-trips the set', () async {
    await WantToPlayStore.write({5, 9});
    expect(await WantToPlayStore.read(), {5, 9});
  });

  test('write replaces the previous set wholesale', () async {
    await WantToPlayStore.write({5, 9});
    await WantToPlayStore.write({1});
    expect(await WantToPlayStore.read(), {1});
  });

  test('clear empties a previously written set', () async {
    await WantToPlayStore.write({5});
    await WantToPlayStore.clear();
    expect(await WantToPlayStore.read(), isEmpty);
  });

  test('tolerates corrupt stored JSON', () async {
    SharedPreferences.setMockInitialValues({
      'ra_want_to_play_ids': 'not json{',
    });
    expect(await WantToPlayStore.read(), isEmpty);
  });
}
