import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/switch_grouping.dart';

// Invented titles; the filename *shape* is what these cover, so the bracketed
// ids, versions and dumper tags follow the real layout while the names do not.
const _base = 'Sample Game [0100AAA0BBBC4000][v0][Base][XCI][US].xci';
const _update = 'Sample Game [0100AAA0BBBC4800][v720896][1.12.0][UPD].nsp';
const _dlc = 'Sample Game Sample Game - Bonus Pack [0100AAA0BBBC5001][v0].nsp';

void main() {
  test('title id decides the part', () {
    expect(switchPart(_base), SwitchPart.base);
    expect(switchPart(_update), SwitchPart.update);
    expect(switchPart(_dlc), SwitchPart.dlc);
    // DLC sits at base + 0x1000 + index, so the nibble before the index moves:
    // a base ending C000 has its DLC at D001, D002, …
    expect(switchPart('Third Title Extra Skin [0100AAA0BBBBD002][v0].nsp'),
        SwitchPart.dlc);
  });

  test('base, update and DLC of one title share a group key', () {
    expect(switchGroupKey(_base), '0100AAA0BBBC0000');
    expect(switchGroupKey(_update), switchGroupKey(_base));
    expect(switchGroupKey(_dlc), switchGroupKey(_base));
  });

  test('a different title gets a different key', () {
    expect(switchGroupKey('Second Title [0100DDD0EEEF2000][v0].nsp'),
        isNot(switchGroupKey(_base)));
  });

  test('non-Switch files are never grouped or parted', () {
    expect(switchGroupKey('Some Old Game (USA, Europe).md'), isNull);
    expect(switchTitleId('Another Old Game (USA) [0100AAA0BBBC4000].sfc'),
        isNull);
  });

  test('files with no title id fall back to dumper markers', () {
    expect(switchPart('Marker Only Game.nsp'), SwitchPart.base);
    expect(switchPart('Marker Only Game [Update].nsp'), SwitchPart.update);
    expect(
        switchPart('Marker Only Game [Wave 1-6 DLC Unlocker]'
            '[0100AAA0BBBC300x][v1114112].nsp'),
        SwitchPart.dlc);
    // No title id means no group: a name-only key would also collapse the
    // region variants of ordinary ROMs.
    expect(switchGroupKey('Marker Only Game.nsp'), isNull);
  });

  test('parts sort base first, then updates oldest to newest, then DLC', () {
    const older = 'Sample Game [0100AAA0BBBC4800][v196608].nsp';
    const newer = 'Sample Game [0100AAA0BBBC4800][v589824].nsp';
    final files = [_dlc, newer, older, _base]..sort(compareSwitchParts);
    expect(files, [_base, older, newer, _dlc]);
  });

  test('display title drops the bracketed ids, versions and tags', () {
    expect(switchDisplayTitle(_base), 'Sample Game');
    // Dumpers substitute characters the filesystem rejects; they stay in the
    // title, only the bracketed blocks go.
    expect(
        switchDisplayTitle(
            'Example Title™ 4꞉ Sequel [0100DDD0EEEF2000][v0][Base][XCI].xci'),
        'Example Title™ 4꞉ Sequel');
  });

  test('part labels name updates by version and number repeated DLC', () {
    expect(switchPartLabels([_base, _update, _dlc]),
        ['Base', 'Update 1.12.0', 'DLC']);
    expect(
        switchPartLabels([
          _base,
          'Sample Game [0100AAA0BBBC4800][v262144].nsp',
          _dlc,
          'Sample Game Extra Skin [0100AAA0BBBC5002][v0].nsp',
        ]),
        ['Base', 'Update v4', 'DLC 1', 'DLC 2']);
  });
}
