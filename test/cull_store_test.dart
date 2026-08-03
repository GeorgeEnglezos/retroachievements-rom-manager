import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/cull_store.dart';
import 'package:rarm/services/playlist_store.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().resetForTest();
    CullStore().resetForTest();
  });

  test('keep marks the key decided with no playlist side effect', () async {
    final store = CullStore();
    await store.decide('ra:1', CullVerdict.keep);
    expect(await store.decided(), {'ra:1'});
    expect(await PlaylistStore().playlistsContaining('ra:1'), isEmpty);
  });

  test('trash adds the key to the Trash playlist', () async {
    await CullStore().decide('ra:2', CullVerdict.trash);
    expect(await PlaylistStore().playlistsContaining('ra:2'), {trashId});
  });

  test('favorite adds the key to Favorites', () async {
    await CullStore().decide('ra:3', CullVerdict.favorite);
    expect(await PlaylistStore().playlistsContaining('ra:3'), {favoritesId});
  });

  test('a trash verdict moves every disc key to Trash', () async {
    await CullStore().decide('path:A1', CullVerdict.trash,
        trashKeys: {'path:A1', 'path:A2'});
    // The decided set stays keyed by the primary only.
    expect(await CullStore().decided(), {'path:A1'});
    expect(await PlaylistStore().playlistsContaining('path:A1'), {trashId});
    expect(await PlaylistStore().playlistsContaining('path:A2'), {trashId});
  });

  test('undecide reverses a verdict and its playlist side effect', () async {
    final store = CullStore();
    await store.decide('ra:1', CullVerdict.keep);
    final added = await store.decide('ra:2', CullVerdict.trash);

    await store.undecide('ra:2', CullVerdict.trash, addedKeys: added);
    expect(await store.decided(), {'ra:1'});
    expect(await PlaylistStore().playlistsContaining('ra:2'), isEmpty);

    await store.undecide('ra:1', CullVerdict.keep);
    expect(await store.decided(), isEmpty);
  });

  test('undecide takes a whole disc set back out of Trash', () async {
    final store = CullStore();
    const keys = {'path:A1', 'path:A2'};
    final added = await store.decide('path:A1', CullVerdict.trash,
        trashKeys: keys);
    expect(added, keys);
    await store.undecide('path:A1', CullVerdict.trash, addedKeys: added);
    expect(await store.decided(), isEmpty);
    expect(await PlaylistStore().playlistsContaining('path:A2'), isEmpty);
  });

  test('undecide of a favorite drops it from Favorites', () async {
    final store = CullStore();
    final added = await store.decide('ra:3', CullVerdict.favorite);
    await store.undecide('ra:3', CullVerdict.favorite, addedKeys: added);
    expect(await store.decided(), isEmpty);
    expect(await PlaylistStore().playlistsContaining('ra:3'), isEmpty);
  });

  test('undecide keeps a Trash membership that predates the verdict', () async {
    final store = CullStore();
    // Trashed by hand months ago, then trashed again in the deck.
    await PlaylistStore().addMember(trashId, 'ra:9');
    final added = await store.decide('ra:9', CullVerdict.trash);
    expect(added, isEmpty, reason: 'the verdict added nothing new');

    await store.undecide('ra:9', CullVerdict.trash, addedKeys: added);
    expect(await store.decided(), isEmpty);
    expect(await PlaylistStore().playlistsContaining('ra:9'), {trashId});
  });

  test('undecide keeps a Favorites membership that predates the verdict',
      () async {
    final store = CullStore();
    await PlaylistStore().addMember(favoritesId, 'ra:8');
    final added = await store.decide('ra:8', CullVerdict.favorite);
    await store.undecide('ra:8', CullVerdict.favorite, addedKeys: added);
    expect(await PlaylistStore().playlistsContaining('ra:8'), {favoritesId});
  });

  test('a partly-trashed disc set only gives back the discs it added',
      () async {
    final store = CullStore();
    await PlaylistStore().addMember(trashId, 'path:A1');
    final added = await store.decide('path:A1', CullVerdict.trash,
        trashKeys: {'path:A1', 'path:A2'});
    expect(added, {'path:A2'});

    await store.undecide('path:A1', CullVerdict.trash, addedKeys: added);
    expect(await PlaylistStore().playlistsContaining('path:A1'), {trashId});
    expect(await PlaylistStore().playlistsContaining('path:A2'), isEmpty);
  });

  test('decisions persist across a reload', () async {
    await CullStore().decide('ra:1', CullVerdict.keep);
    // Simulate a fresh app run over the same prefs: clear memory, keep prefs.
    CullStore().resetForTest();
    expect(await CullStore().decided(), {'ra:1'});
  });

  test('resetConsole clears only the given keys and leaves playlists', () async {
    final store = CullStore();
    await store.decide('ra:1', CullVerdict.trash);
    await store.decide('ra:2', CullVerdict.keep);
    await store.decide('path:C', CullVerdict.keep);
    await store.resetConsole(['ra:1', 'ra:2']);
    expect(await store.decided(), {'path:C'});
    // Trashed games stay in Trash after a reset.
    expect(await PlaylistStore().playlistsContaining('ra:1'), {trashId});
  });
}
