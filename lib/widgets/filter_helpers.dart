export '../models/rom_result.dart' show statusLabel;

import '../services/rom_filter.dart';

/// Display label for a progress-state chip.
String progressLabel(ProgressState s) => switch (s) {
      ProgressState.notStarted => 'Not started',
      ProgressState.started => 'Started',
      ProgressState.nearComplete => 'Near complete',
      ProgressState.mastered => 'Mastered',
    };

/// Returns a new set with [v] toggled (added if absent, removed if present).
Set<T> toggleSet<T>(Set<T> set, T v) {
  final next = {...set};
  next.contains(v) ? next.remove(v) : next.add(v);
  return next;
}

/// Returns a new set with [v] removed; never mutates [set].
Set<T> withoutSet<T>(Set<T> set, T v) => {...set}..remove(v);

/// Resolves a playlist id to its name, falling back to the id when unknown.
String playlistName(List<({String id, String name})> playlists, String id) =>
    playlists.firstWhere((p) => p.id == id, orElse: () => (id: id, name: id)).name;
