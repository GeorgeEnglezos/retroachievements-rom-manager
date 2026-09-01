import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rarm/services/app_mode.dart';
import 'package:rarm/services/play_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appModeListenable.value = AppMode.cleaning;
    playViewListenable.value = const PlayView();
  });

  test('round-trips through JSON', () {
    const v = PlayView(
      fileName: true,
      fileSize: true,
      achievementCount: false,
      hot: false,
      noAchievements: true,
      fileTags: true,
      raTitle: false,
      layout: PlayLayout.grid,
    );
    expect(PlayView.fromJson(v.toJson()).toJson(), v.toJson());
  });

  test('fromJson falls back to the defaults for missing keys', () {
    // A setting added after the user last saved must read as its default, not
    // as off, so an upgrade doesn't silently blank someone's listings.
    expect(PlayView.fromJson(const {}).toJson(), const PlayView().toJson());
  });

  test('copyWith changes only the named field', () {
    const base = PlayView();
    expect(base.copyWith(hot: false).hot, isFalse);
    expect(base.copyWith(hot: false).achievementCount,
        base.achievementCount);
    expect(base.copyWith(fileTags: true).fileTags, isTrue);
    expect(base.copyWith(fileTags: true).hot, base.hot);
    expect(base.copyWith(layout: PlayLayout.grid).layout, PlayLayout.grid);
    expect(base.copyWith(layout: PlayLayout.grid).raTitle, base.raTitle);
  });

  test('save then load survives a restart', () async {
    await savePlayView(const PlayView(hot: false, layout: PlayLayout.list));
    playViewListenable.value = const PlayView();
    await initPlayView();
    expect(playViewListenable.value.hot, isFalse);
    expect(playViewListenable.value.layout, PlayLayout.list);
  });

  test('a corrupt stored value leaves the defaults in place', () async {
    SharedPreferences.setMockInitialValues({'play_view': 'not json'});
    await initPlayView();
    expect(playViewListenable.value.toJson(), const PlayView().toJson());
  });

  test('cleaning mode ignores the play settings', () {
    playViewListenable.value =
        const PlayView(hot: false, fileTags: false, raTitle: false);
    expect(playView.hot, isTrue);
    expect(playView.fileTags, isTrue);
    expect(playView.raTitle, isTrue);

    appModeListenable.value = AppMode.gaming;
    expect(playView.hot, isFalse);
    expect(playView.fileTags, isFalse);
    expect(playView.raTitle, isFalse);
  });

  test('listingTitle uses the file name when RA titles are off', () {
    appModeListenable.value = AppMode.gaming;

    playViewListenable.value = const PlayView(raTitle: false);
    expect(listingTitle('Super Mario World', 'smw.sfc'), 'smw.sfc');

    playViewListenable.value = const PlayView();
    expect(listingTitle('Super Mario World', 'smw.sfc'), 'Super Mario World');
    // A placeholder RA title still falls back, as gameDisplayName decides.
    expect(listingTitle('GAME #1100002368', 'smw.sfc'), 'smw.sfc');
  });
}
