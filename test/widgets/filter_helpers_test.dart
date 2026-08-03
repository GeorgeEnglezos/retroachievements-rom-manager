import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/rom_filter.dart';
import 'package:rarm/widgets/filter_helpers.dart';

void main() {
  test('statusLabel maps known statuses', () {
    expect(statusLabel(RomStatus.supported), 'Supported');
    expect(statusLabel(RomStatus.unsupported), 'No match');
    expect(statusLabel(RomStatus.notFetched), 'Not fetched');
    expect(statusLabel(RomStatus.error), 'Error');
  });

  test('statusLabel falls back to enum name for other values', () {
    expect(statusLabel(RomStatus.checking), 'checking');
  });

  test('progressLabel maps states', () {
    expect(progressLabel(ProgressState.notStarted), 'Not started');
    expect(progressLabel(ProgressState.started), 'Started');
    expect(progressLabel(ProgressState.mastered), 'Mastered');
  });

  test('toggleSet adds when absent, removes when present', () {
    expect(toggleSet(<int>{1}, 2), {1, 2});
    expect(toggleSet(<int>{1, 2}, 2), {1});
  });

  test('withoutSet removes without mutating the original', () {
    final original = {1, 2};
    expect(withoutSet(original, 2), {1});
    expect(original, {1, 2});
  });

  test('playlistName resolves id, falling back to the id itself', () {
    final pls = [(id: 'a', name: 'Favorites')];
    expect(playlistName(pls, 'a'), 'Favorites');
    expect(playlistName(pls, 'missing'), 'missing');
  });
}
