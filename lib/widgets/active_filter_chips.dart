import 'package:flutter/material.dart';
import '../services/rom_filter.dart';
import 'ui/ui_chip.dart';
import 'filter_helpers.dart';

/// Builds the removable active-filter chips for [filter]. Returned as a list so
/// callers can interleave them in their own Wrap/Row. Each chip clears exactly
/// its own criterion on remove.
List<Widget> activeFilterChips({
  required RomFilter filter,
  required List<({String id, String name})> playlists,
  required ValueChanged<RomFilter> onChanged,
}) {
  final f = filter;
  final chips = <Widget>[];
  for (final s in f.statuses) {
    chips.add(UiChip(
      key: ValueKey('status-${s.name}'),
      label: statusLabel(s),
      selected: true,
      onRemove: () => onChanged(f.copyWith(statuses: withoutSet(f.statuses, s))),
    ));
  }
  for (final g in f.genres) {
    chips.add(UiChip(
      key: ValueKey('genre-$g'),
      label: g,
      selected: true,
      onRemove: () => onChanged(f.copyWith(genres: withoutSet(f.genres, g))),
    ));
  }
  for (final ps in f.progressStates) {
    chips.add(UiChip(
      key: ValueKey('progress-${ps.name}'),
      label: progressLabel(ps),
      selected: true,
      onRemove: () =>
          onChanged(f.copyWith(progressStates: withoutSet(f.progressStates, ps))),
    ));
  }
  if (f.onlyRecentlyPlayed) {
    chips.add(UiChip(
      key: const ValueKey('active-recently-played'),
      label: 'Recently played',
      selected: true,
      onRemove: () => onChanged(f.copyWith(onlyRecentlyPlayed: false)),
    ));
  }
  for (final t in f.tags) {
    chips.add(UiChip(
      key: ValueKey('tag-$t'),
      label: t,
      selected: true,
      onRemove: () => onChanged(f.copyWith(tags: withoutSet(f.tags, t))),
    ));
  }
  for (final id in f.includePlaylistIds) {
    chips.add(UiChip(
      key: ValueKey('inc-$id'),
      label: '${playlistName(playlists, id)}: only',
      selected: true,
      onRemove: () => onChanged(
          f.copyWith(includePlaylistIds: withoutSet(f.includePlaylistIds, id))),
    ));
  }
  for (final id in f.excludePlaylistIds) {
    chips.add(UiChip(
      key: ValueKey('exc-$id'),
      label: '${playlistName(playlists, id)}: exclude',
      selected: true,
      onRemove: () => onChanged(
          f.copyWith(excludePlaylistIds: withoutSet(f.excludePlaylistIds, id))),
    ));
  }
  return chips;
}
