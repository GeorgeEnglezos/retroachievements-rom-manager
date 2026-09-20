import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/favorite_systems.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggle adds then removes, and survives a re-read', () async {
    expect(await FavoriteSystems.all(), isEmpty);

    await FavoriteSystems.toggle('/roms/Zapbox');
    expect(await FavoriteSystems.all(), {'zapbox'});

    await FavoriteSystems.toggle('/roms/Zapbox');
    expect(await FavoriteSystems.all(), isEmpty);
  });

  test('favorites are matched by folder name, not by path', () async {
    final favorites = await FavoriteSystems.toggle('/roms/Zapbox');
    expect(
        FavoriteSystems.isFavorite(favorites, ['/other/drive/zapbox']), isTrue);
    expect(FavoriteSystems.isFavorite(favorites, ['/roms/Nebula']), isFalse);
  });

  test('a group is favorite when any of its folders is', () async {
    final favorites = await FavoriteSystems.toggle('/roms/Zapbox');
    expect(
        FavoriteSystems.isFavorite(
            favorites, ['/roms/Nebula', '/roms/Zapbox']),
        isTrue);
    expect(FavoriteSystems.isFavorite(favorites, const []), isFalse);
  });
}
