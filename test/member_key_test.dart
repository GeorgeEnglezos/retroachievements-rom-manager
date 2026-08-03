import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/member_key.dart';

void main() {
  // Stored in playlists on disk; changing either format orphans saved members.
  test('matched game keys by game id, unmatched by path', () {
    expect(memberKeyFor(gameId: 42, filePath: '/x/a.nes'), 'ra:42');
    expect(memberKeyFor(gameId: null, filePath: '/x/a.nes'), 'path:/x/a.nes');
  });
}
