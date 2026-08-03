import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/log_service.dart';

void main() {
  // Regression: importFromDirectory runs findGamelists/importFrom (which log)
  // inside Isolate.run. A background isolate has no Flutter binding, so
  // LogService must not touch SchedulerBinding.instance there; doing so threw
  // "Binding has not yet been initialized" and crashed the import.
  test('LogService.error is safe to call from a background isolate', () async {
    final r = await Isolate.run(() {
      LogService.error('Repro', 'boom', err: StateError('x'));
      return 42;
    });
    expect(r, 42);
  });
}
