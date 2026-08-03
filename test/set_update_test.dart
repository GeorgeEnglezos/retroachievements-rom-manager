import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/set_update.dart';

void main() {
  test('flags a grown set', () {
    expect(isSetUpdate(10, 12), isTrue);
  });

  test('no flag when count is unchanged or shrank', () {
    expect(isSetUpdate(10, 10), isFalse);
    expect(isSetUpdate(10, 8), isFalse);
  });

  test('no flag when either count is unknown', () {
    expect(isSetUpdate(null, 12), isFalse);
    expect(isSetUpdate(10, null), isFalse);
    expect(isSetUpdate(null, null), isFalse);
  });
}
