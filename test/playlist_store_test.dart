import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rarm/services/playlist_store.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PlaylistStore().clear();
  });

  test('Favorites is seeded and listed first', () async {
    final all = await PlaylistStore().all();
    expect(all.first.id, 'favorites');
    expect(all.first.builtin, isTrue);
  });

  test('create adds a custom playlist', () async {
    final store = PlaylistStore();
    final pl = await store.create('Co-op Night');
    expect(pl.name, 'Co-op Night');
    expect(pl.builtin, isFalse);
    final all = await store.all();
    expect(all.any((p) => p.id == pl.id), isTrue);
  });

  test('addMember / removeMember', () async {
    final store = PlaylistStore();
    await store.addMember('favorites', 'ra:42');
    expect(await store.playlistsContaining('ra:42'), contains('favorites'));
    await store.removeMember('favorites', 'ra:42');
    expect(await store.playlistsContaining('ra:42'), isNot(contains('favorites')));
  });

  test('rename a custom playlist', () async {
    final store = PlaylistStore();
    final pl = await store.create('Old');
    await store.rename(pl.id, 'New');
    final all = await store.all();
    expect(all.firstWhere((p) => p.id == pl.id).name, 'New');
  });

  test('delete a custom playlist', () async {
    final store = PlaylistStore();
    final pl = await store.create('Temp');
    await store.delete(pl.id);
    final all = await store.all();
    expect(all.any((p) => p.id == pl.id), isFalse);
  });

  test('Favorites cannot be deleted', () async {
    final store = PlaylistStore();
    await store.delete('favorites');
    final all = await store.all();
    expect(all.any((p) => p.id == 'favorites'), isTrue);
  });

  test('persists across instances', () async {
    final pl = await PlaylistStore().create('Keep');
    final all = await PlaylistStore().all();
    expect(all.any((p) => p.id == pl.id), isTrue);
  });

  test('playlistsContaining checks every playlist', () async {
    final store = PlaylistStore();
    final a = await store.create('A');
    await store.addMember(a.id, 'ra:1');
    await store.addMember('favorites', 'ra:1');
    final ids = await store.playlistsContaining('ra:1');
    expect(ids, containsAll([a.id, 'favorites']));
  });

  test('tolerates corrupt stored JSON', () async {
    SharedPreferences.setMockInitialValues({'playlists': 'not json{'});
    final all = await PlaylistStore().all();
    expect(all.first.id, 'favorites'); // reseeded
  });

  test('Played builtin is seeded and listed second', () async {
    final all = await PlaylistStore().all();
    expect(all[0].id, 'favorites');
    expect(all[1].id, 'played');
    expect(all[1].builtin, isTrue);
    expect(all[1].name, 'Played');
  });

  test('Played cannot be deleted', () async {
    final store = PlaylistStore();
    await store.delete('played');
    final all = await store.all();
    expect(all.any((p) => p.id == 'played'), isTrue);
  });

  test('setMembers replaces all members atomically', () async {
    final store = PlaylistStore();
    await store.addMember('played', 'ra:1');
    await store.addMember('played', 'ra:2');
    await store.setMembers('played', {'ra:3', 'ra:4'});
    final pl = (await store.all()).firstWhere((p) => p.id == 'played');
    expect(pl.members, equals({'ra:3', 'ra:4'}));
  });

  test('setMembers with empty set clears all members', () async {
    final store = PlaylistStore();
    await store.addMember('played', 'ra:1');
    await store.setMembers('played', {});
    final pl = (await store.all()).firstWhere((p) => p.id == 'played');
    expect(pl.members, isEmpty);
  });

  test('Trash is seeded, builtin, and listed after Played', () async {
    final all = await PlaylistStore().all();
    expect(all[1].id, playedId);
    expect(all[2].id, trashId);
    expect(all[2].builtin, isTrue);
  });

  test('visibleMemberCount ignores members the library can no longer show',
      () async {
    final store = PlaylistStore();
    await store.addMember(trashId, 'ra:1');
    await store.addMember(trashId, 'path:/roms/deleted.sfc');
    final pl = (await store.all()).firstWhere((p) => p.id == trashId);

    expect(visibleMemberCount(pl, {'ra:1'}), 1);
    // The membership itself is kept: the game comes back if the ROM does.
    expect(pl.members, hasLength(2));
    expect(visibleMemberCount(pl, {'ra:1', 'path:/roms/deleted.sfc'}), 2);
  });

  test('addMember reports whether the key was new', () async {
    final store = PlaylistStore();
    expect(await store.addMember(trashId, 'ra:1'), isTrue);
    expect(await store.addMember(trashId, 'ra:1'), isFalse);
  });

  // Screens kept alive off-stage (Home in the shell's IndexedStack) only learn
  // about a cull verdict or a bulk action through this.
  test('every write notifies listeners', () async {
    final store = PlaylistStore();
    var notifications = 0;
    void count() => notifications++;
    store.addListener(count);
    addTearDown(() => store.removeListener(count));

    await store.addMember(favoritesId, 'ra:1');
    expect(notifications, 1);
    await store.removeMember(favoritesId, 'ra:1');
    expect(notifications, 2);
    await store.toggleMember(favoritesId, 'ra:1');
    expect(notifications, 3);
    await store.create('Night');
    expect(notifications, 4);
  });

  test('setMembers with unchanged members writes nothing and stays quiet',
      () async {
    final store = PlaylistStore();
    await store.setMembers(playedId, {'ra:1'});
    var notifications = 0;
    void count() => notifications++;
    store.addListener(count);
    addTearDown(() => store.removeListener(count));

    await store.setMembers(playedId, {'ra:1'});
    expect(notifications, 0, reason: 'a re-derived Played must not loop');
    await store.setMembers(playedId, {'ra:1', 'ra:2'});
    expect(notifications, 1);
  });

  test('Trash cannot be renamed or deleted', () async {
    final store = PlaylistStore();
    await store.rename(trashId, 'Nope');
    await store.delete(trashId);
    final all = await store.all();
    expect(all[2].id, trashId);
    expect(all[2].name, 'Trash');
  });
}
