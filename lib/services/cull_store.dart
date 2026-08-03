import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playlist_store.dart';

// Single-service key, so it stays private here (see pref_keys.dart).
const _prefKey = 'cull_decided';

enum CullVerdict { keep, trash, favorite }

/// Persists which games the elimination game has decided on, as a set of
/// member keys (see member_key.dart). Trash/favorite verdicts also add the key
/// to the matching playlist.
///
/// The decided set and playlist membership are independent: taking a game out
/// of the Trash playlist by hand does not un-decide it, so it stays out of the
/// deck. Only [undecide] (the deck's undo) or [resetConsole] ("start over")
/// bring a game back.
class CullStore {
  // Shared singleton, same pattern as PlaylistStore: every screen sees the
  // same live decided set.
  CullStore._();
  static final CullStore _instance = CullStore._();
  factory CullStore() => _instance;

  final Set<String> _decided = {};
  bool _loaded = false;

  // Only for tests, which reset the shared singleton between cases.
  @visibleForTesting
  void resetForTest() {
    _decided.clear();
    _loaded = false;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _decided.addAll(prefs.getStringList(_prefKey) ?? const []);
    _loaded = true;
  }

  Future<Set<String>> decided() async {
    await _ensureLoaded();
    return Set.of(_decided);
  }

  /// Marks [memberKey] decided and applies the verdict's playlist side effect.
  /// [trashKeys] is every key a trash verdict should move to Trash (one per
  /// disc of a multi-disc set), defaulting to [memberKey] alone; Favorites
  /// always uses [memberKey], the key the card's heart reads.
  ///
  /// Returns the keys this verdict actually added to a playlist, which is what
  /// [undecide] needs to reverse it. Keys already in Trash/Favorites before the
  /// swipe are not in the set, so undoing can't take back a decision the user
  /// made outside the deck.
  Future<Set<String>> decide(String memberKey, CullVerdict verdict,
      {Set<String>? trashKeys}) async {
    await _ensureLoaded();
    _decided.add(memberKey);
    final added = <String>{};
    switch (verdict) {
      case CullVerdict.trash:
        for (final key in trashKeys ?? {memberKey}) {
          if (await PlaylistStore().addMember(trashId, key)) added.add(key);
        }
      case CullVerdict.favorite:
        if (await PlaylistStore().addMember(favoritesId, memberKey)) {
          added.add(memberKey);
        }
      case CullVerdict.keep:
        break;
    }
    await _persist();
    return added;
  }

  /// Reverses one verdict: forgets the decision and removes only the playlist
  /// memberships that verdict added, which [decide] returned as [addedKeys].
  /// The caller (the deck) owns the undo stack, so undo only ever reaches cards
  /// from the run it is showing.
  Future<void> undecide(String memberKey, CullVerdict verdict,
      {Set<String> addedKeys = const {}}) async {
    await _ensureLoaded();
    _decided.remove(memberKey);
    switch (verdict) {
      case CullVerdict.trash:
        for (final key in addedKeys) {
          await PlaylistStore().removeMember(trashId, key);
        }
      case CullVerdict.favorite:
        for (final key in addedKeys) {
          await PlaylistStore().removeMember(favoritesId, key);
        }
      case CullVerdict.keep:
        break;
    }
    await _persist();
  }

  /// "Start over" for one console: forgets the given decisions so the games
  /// re-enter the deck. Playlists are untouched (trashed games stay in Trash).
  Future<void> resetConsole(Iterable<String> memberKeys) async {
    await _ensureLoaded();
    _decided.removeAll(memberKeys);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefKey, _decided.toList());
  }
}
