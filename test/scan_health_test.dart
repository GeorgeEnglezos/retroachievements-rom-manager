import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/home_index.dart';
import 'package:rarm/services/scan_health.dart';

SearchIndexEntry _row({
  bool matched = false,
  bool noMatch = false,
  int? earned,
}) =>
    SearchIndexEntry(
      title: 't',
      fileName: 'f',
      filePath: 'p',
      systemPath: 'sp',
      systemName: 'NES',
      gameId: matched ? 1 : null,
      matched: matched,
      noMatch: noMatch,
      md5: null,
      icon: null,
      earnedAchievements: earned,
    );

SystemSummary _sys(int bytes) => SystemSummary(
      systemPath: 'sp',
      systemId: 'id',
      name: 'NES',
      consoleId: 7,
      totalGames: 3,
      gamesScanned: 3,
      gamesWithAchievements: 1,
      totalSizeBytes: bytes,
      lastScanned: null,
    );

void main() {
  test('counts supported / unsupported / not fetched / with progress', () {
    final rows = [
      _row(matched: true, earned: 5),
      _row(matched: true, earned: 0),
      _row(noMatch: true),
      _row(), // not fetched
    ];
    final h = ScanHealth.fromIndex([_sys(100), _sys(200)], rows);

    expect(h.totalRoms, 4);
    expect(h.supported, 2);
    expect(h.unsupported, 1);
    expect(h.notFetched, 1);
    expect(h.withProgress, 1);
    expect(h.systems, 2);
    expect(h.totalSizeBytes, 300);
  });

  test('supportedRatio ignores not-fetched and is 0 when nothing resolved', () {
    expect(ScanHealth.fromIndex([], [_row(), _row()]).supportedRatio, 0);
    final h =
        ScanHealth.fromIndex([], [_row(matched: true), _row(noMatch: true)]);
    expect(h.supportedRatio, 0.5);
  });
}
