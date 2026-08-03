import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/models/game_metadata.dart';

void main() {
  test('round-trips through JSON', () {
    const m = GameMetadata(
      providerId: 'screenscraper',
      title: 'Some Racer',
      publisher: 'Acme',
      developer: 'Acme Studio',
      genre: 'Racing',
      released: '1999',
      imageUrl: 'https://cdn.example.com/cover.png',
      matchConfidence: 0.82,
      sourceRef: 'ss:12345',
    );
    final back = GameMetadata.fromJson(m.toJson());
    expect(back.providerId, 'screenscraper');
    expect(back.title, 'Some Racer');
    expect(back.publisher, 'Acme');
    expect(back.imageUrl, 'https://cdn.example.com/cover.png');
    expect(back.matchConfidence, 0.82);
    expect(back.sourceRef, 'ss:12345');
  });

  test('matchConfidence defaults to 1.0, in the constructor and on old JSON',
      () {
    expect(const GameMetadata(providerId: 'ra', title: 'X').matchConfidence, 1.0);
    // Old JSON without the field still loads as a full-confidence match.
    final back = GameMetadata.fromJson({'providerId': 'ra', 'title': 'X'});
    expect(back.matchConfidence, 1.0);
  });
}
