import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/rom_result.dart';
import 'package:rarm/services/couch_rows.dart';

RomResult _g(String path, {String? console, int players = 0}) =>
    RomResult(filePath: path, fileName: '${path.split('/').last}.sfc')
      ..consoleName = console
      ..numPlayersCasual = players;

void main() {
  group('playNextRows', () {
    test('groups by console, shelves sorted, null under Other', () {
      final r = playNextRows([
        _g('a', console: 'SNES'),
        _g('b', console: 'Genesis'),
        _g('c', console: 'SNES'),
        _g('d', console: null),
      ]);
      expect(r.consoles.map((c) => c.title), ['Genesis', 'Other', 'SNES']);
      expect(r.consoles.firstWhere((c) => c.title == 'SNES').games.length, 2);
    });

    test('each console is ordered by casual players, most first', () {
      final r = playNextRows([
        _g('quiet', console: 'SNES', players: 12),
        _g('hot', console: 'SNES', players: 900),
      ]);
      expect(r.consoles.single.games.map((g) => g.filePath), ['hot', 'quiet']);
    });

    test('overall row merges every console into one hottest-first list', () {
      final r = playNextRows([
        _g('snes', console: 'SNES', players: 100),
        _g('gen', console: 'Genesis', players: 400),
      ]);
      expect(r.overall.title, 'All Consoles');
      expect(r.overall.games.map((g) => g.filePath), ['gen', 'snes']);
    });
  });
}
