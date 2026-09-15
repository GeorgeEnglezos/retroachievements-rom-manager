import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/widgets/bigpicture/couch_home.dart';

void main() {
  group('couchFillTileSize', () {
    test('a taller column grows the tiles', () {
      expect(CouchHome.couchFillTileSize(1200, 3),
          greaterThan(CouchHome.couchFillTileSize(900, 3)));
    });

    test('a short window bottoms out at the floor, like an unknown row count',
        () {
      // Too short to give three rows room: clamps to the minimum, the same
      // size the compact layout uses (rowCount 0 short-circuits to it).
      expect(CouchHome.couchFillTileSize(300, 3),
          CouchHome.couchFillTileSize(999, 0));
    });

    test('a very tall window stops growing at the ceiling', () {
      expect(CouchHome.couchFillTileSize(5000, 3),
          CouchHome.couchFillTileSize(3000, 3));
    });

    test('a normal window lands strictly between floor and ceiling', () {
      final mid = CouchHome.couchFillTileSize(900, 3);
      expect(mid, greaterThan(CouchHome.couchFillTileSize(300, 3)));
      expect(mid, lessThan(CouchHome.couchFillTileSize(5000, 3)));
    });
  });
}
