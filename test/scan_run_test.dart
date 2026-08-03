import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/scan_progress.dart';
import 'package:rarm/services/scan_run.dart';

void main() {
  // ScanProgress is a singleton, so every test starts from a stopped bar.
  setUp(() => ScanProgress.instance.stop());
  tearDown(() => ScanProgress.instance.stop());

  test('start publishes an indeterminate running bar', () {
    ScanRun().start(label: 'NES');

    expect(ScanProgress.instance.running, isTrue);
    expect(ScanProgress.instance.value, isNull);
    expect(ScanProgress.instance.label, 'NES');
  });

  test('tick advances the published fraction', () {
    final run = ScanRun()..start(total: 4, label: 'NES');

    run.tick();
    expect(ScanProgress.instance.value, 0.25);

    run.tick();
    expect(ScanProgress.instance.value, 0.5);
    expect(run.done, 2);
  });

  test('addTotal grows the denominator across folders', () {
    final run = ScanRun()..start();
    run.addTotal(2);
    run.tick();
    expect(ScanProgress.instance.value, 0.5);

    run.addTotal(2);
    expect(run.total, 4);
    expect(ScanProgress.instance.value, 0.25);
  });

  test('relabel changes the label without advancing', () {
    final run = ScanRun()..start(total: 2, label: 'NES');
    run.tick();
    run.relabel('SNES');

    expect(ScanProgress.instance.label, 'SNES');
    expect(run.done, 1);
  });

  test('cancel from the bar latches on the run', () {
    final run = ScanRun()..start(total: 2);
    expect(run.cancelled, isFalse);

    ScanProgress.instance.requestCancel();
    expect(run.cancelled, isTrue);

    // Later ticks must not clear the latch by republishing a fresh onCancel.
    run.tick();
    expect(run.cancelled, isTrue);
  });

  test('stop clears the bar', () {
    ScanRun()
      ..start(total: 2)
      ..stop();

    expect(ScanProgress.instance.running, isFalse);
  });

  test('busy reports whether any run holds the bar', () {
    expect(ScanRun.busy, isFalse);
    final run = ScanRun()..start();
    expect(ScanRun.busy, isTrue);
    run.stop();
    expect(ScanRun.busy, isFalse);
  });
}
