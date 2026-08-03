import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/single_instance.dart';

void main() {
  // A test-only port so this never collides with a running app on the real one.
  const testPort = 51919;

  test('second acquire fails while the first holds the lock', () async {
    expect(await SingleInstance.acquire(port: testPort), isTrue);
    // Same process, port already bound → a would-be second instance bails.
    expect(await SingleInstance.acquire(port: testPort), isFalse);
    await SingleInstance.release();
    // Lock freed → available again.
    expect(await SingleInstance.acquire(port: testPort), isTrue);
    await SingleInstance.release();
  });
}
