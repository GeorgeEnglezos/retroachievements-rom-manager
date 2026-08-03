import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/hotness.dart';

RomResult _rom({required RomStatus status, int? players}) =>
    RomResult(filePath: 'x.gba', fileName: 'x.gba')
      ..status = status
      ..numPlayersCasual = players;

void main() {
  group('isHotGame', () {
    test('matched game at/above the threshold is hot', () {
      expect(
          isHotGame(_rom(
              status: RomStatus.supported, players: hotPlayerThreshold)),
          isTrue);
      expect(
          isHotGame(_rom(
              status: RomStatus.supported, players: hotPlayerThreshold + 1)),
          isTrue);
    });

    test('below threshold, unmatched, or unknown player count is not hot', () {
      expect(
          isHotGame(_rom(
              status: RomStatus.supported, players: hotPlayerThreshold - 1)),
          isFalse);
      expect(isHotGame(_rom(status: RomStatus.supported, players: null)),
          isFalse);
      // A very popular but not-matched file (no RA set applied) isn't hot.
      expect(
          isHotGame(_rom(status: RomStatus.notFetched, players: 999999)),
          isFalse);
    });
  });
}
