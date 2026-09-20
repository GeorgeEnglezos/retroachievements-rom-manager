import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pref_keys.dart';

const _prefKey = PrefKeys.playlists;
const favoritesId = 'favorites';
const playedId = 'played';
const trashId = 'trash';

/// A named collection of games. Membership is by member key (see member_key.dart).
class Playlist {
  final String id;
  String name;
  final bool builtin;
  final Set<String> members;

  Playlist({
    required this.id,
    required this.name,
    required this.builtin,
    Set<String>? members,
  }) : members = members ?? {};

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String,
        builtin: j['builtin'] as bool? ?? false,
        members: ((j['members'] as List?) ?? const [])
            .map((e) => e as String)
            .toSet(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'builtin': builtin,
        'members': members.toList(),
      };
}

/// Message for a bulk favorites toggle that added [added] and removed [removed]
/// games, so every screen phrases it the same way.
String favoritesSnack(int added, int removed) {
  final parts = <String>[
    if (added > 0) 'added $added to Favorites',
    if (removed > 0) 'removed $removed from Favorites',
  ];
  return parts.isEmpty ? 'No changes' : parts.join(', ').capitalizeFirst();
}

extension on String {
  String capitalizeFirst() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

/// How many of [pl]'s members are actually in the library right now, given the
/// keys it currently yields. Membership is never deleted for a game that has
/// gone (a key is not stable: a failed rescan drops a game's RA id, and an
/// unplugged drive comes back), so the raw member count would keep counting
/// games the playlist can no longer show.
int visibleMemberCount(Playlist pl, Set<String> liveKeys) =>
    pl.members.where(liveKeys.contains).length;

/// Inverts a playlist list into a `memberKey -> playlist ids` map, used to tell
/// which playlists a ROM belongs to. Lives here so every view builds it the
/// same way.
Map<String, Set<String>> playlistMembership(List<Playlist> playlists) {
  final m = <String, Set<String>>{};
  for (final pl in playlists) {
    for (final key in pl.members) {
      m.putIfAbsent(key, () => {}).add(pl.id);
    }
  }
  return m;
}

/// Persists playlists as one JSON list under [_prefKey]. Favorites is always
/// present (seeded on first load) and cannot be renamed or deleted.
///
/// Notifies on every write, so a screen that is kept alive off-stage (the Home
/// tab behind the shell's IndexedStack) can re-read its counts instead of
/// showing what they were when it was last visited.
class PlaylistStore extends ChangeNotifier {
  // Shared singleton: every screen reads/writes the same live data. Without this
  // each screen kept its own cache and only read prefs once, so a favorite added
  // in one screen was invisible to the (already-loaded) favorites view.
  PlaylistStore._();
  static final PlaylistStore _instance = PlaylistStore._();
  factory PlaylistStore() => _instance;

  final Map<String, Playlist> _mem = {};
  bool _loaded = false;

  /// Empties the shared singleton. Used by a data wipe (see
  /// BackupService.clearAll), and by tests between cases.
  void clear() {
    _mem.clear();
    _loaded = false;
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          final pl = Playlist.fromJson(e as Map<String, dynamic>);
          _mem[pl.id] = pl;
        }
      } catch (_) {
        _mem.clear();
      }
    }
    if (!_mem.containsKey(favoritesId)) {
      _mem[favoritesId] =
          Playlist(id: favoritesId, name: 'Favorites', builtin: true);
    }
    if (!_mem.containsKey(playedId)) {
      _mem[playedId] = Playlist(id: playedId, name: 'Played', builtin: true);
    }
    if (!_mem.containsKey(trashId)) {
      _mem[trashId] = Playlist(id: trashId, name: 'Trash', builtin: true);
    }
    _loaded = true;
  }

  // Favorites first, then Played, then Trash, then custom playlists by name.
  Future<List<Playlist>> all() async {
    await _ensureLoaded();
    final custom = _mem.values.where((p) => !p.builtin).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [_mem[favoritesId]!, _mem[playedId]!, _mem[trashId]!, ...custom];
  }

  Future<Playlist> create(String name) async {
    await _ensureLoaded();
    final id = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    final pl = Playlist(id: id, name: name, builtin: false);
    _mem[id] = pl;
    await _persist();
    return pl;
  }

  Future<void> rename(String id, String name) async {
    await _ensureLoaded();
    final pl = _mem[id];
    if (pl == null || pl.builtin) return;
    pl.name = name;
    await _persist();
  }

  Future<void> delete(String id) async {
    await _ensureLoaded();
    final pl = _mem[id];
    if (pl == null || pl.builtin) return;
    _mem.remove(id);
    await _persist();
  }

  /// Adds [memberKey] to the playlist. Returns true when it was not already a
  /// member, so a caller that may need to reverse itself (the cull deck's undo)
  /// can tell what it actually added from what was already there.
  Future<bool> addMember(String id, String memberKey) async {
    await _ensureLoaded();
    final pl = _mem[id];
    // Unknown playlist or already a member: nothing was added, so don't write
    // or wake listeners. Re-trashing a disc set would otherwise fire one
    // notification per disc for no change.
    if (pl == null || !pl.members.add(memberKey)) return false;
    await _persist();
    return true;
  }

  Future<void> removeMember(String id, String memberKey) async {
    await _ensureLoaded();
    if (_mem[id]?.members.remove(memberKey) != true) return;
    await _persist();
  }

  /// Adds [memberKey] to the playlist if absent, removes it if present.
  /// Returns the new membership state (true = now a member).
  Future<bool> toggleMember(String id, String memberKey) async {
    await _ensureLoaded();
    final pl = _mem[id];
    if (pl == null) return false;
    final nowMember = pl.members.add(memberKey);
    if (!nowMember) pl.members.remove(memberKey);
    await _persist();
    return nowMember;
  }

  Future<void> setMembers(String id, Set<String> members) async {
    await _ensureLoaded();
    final pl = _mem[id];
    if (pl == null) return;
    // Played is re-derived on every library refresh and is usually identical;
    // returning early keeps that from writing prefs and waking listeners (which
    // would refresh again) for nothing.
    if (setEquals(pl.members, members)) return;
    pl.members
      ..clear()
      ..addAll(members);
    await _persist();
  }

  /// Synchronous favorite check for tile rendering. Reads the already-loaded
  /// in-memory store; returns false before the first load (the view rebuilds
  /// once playlists load).
  bool isFavorite(String memberKey) =>
      _mem[favoritesId]?.members.contains(memberKey) ?? false;

  Future<Set<String>> playlistsContaining(String memberKey) async {
    await _ensureLoaded();
    return _mem.values
        .where((p) => p.members.contains(memberKey))
        .map((p) => p.id)
        .toSet();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _mem.values.map((p) => p.toJson()).toList();
    await prefs.setString(_prefKey, jsonEncode(list));
    notifyListeners();
  }
}
