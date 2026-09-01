import 'package:flutter/material.dart';
import '../models/rom_result.dart';
import '../services/rom_filter.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_chip.dart';
import 'ui/ui_dropdown.dart';
import 'filter_helpers.dart';

/// The expandable GB filter panel: Status / Progress / Genre / Playlists chip
/// sections. Stateless, driven by [filter] + [onChanged]. Shared by the folder
/// and playlist toolbars.
class FilterPanel extends StatelessWidget {
  final RomFilter filter;
  final List<String> availableGenres;
  final List<String> availableTags;
  final bool showProgress;
  final List<({String id, String name})> playlists;
  final ValueChanged<RomFilter> onChanged;

  const FilterPanel({
    super.key,
    required this.filter,
    required this.availableGenres,
    this.availableTags = const [],
    required this.showProgress,
    required this.playlists,
    required this.onChanged,
  });

  String _playlistMode(String id) {
    if (filter.includePlaylistIds.contains(id)) return 'only';
    if (filter.excludePlaylistIds.contains(id)) return 'exclude';
    return 'all';
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final f = filter;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ui.surface,
        borderRadius: ui.roundLg,
        border: Border.all(color: ui.border, width: ui.borderWidth),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(context, 'Status', [
            for (final s in const [
              RomStatus.supported,
              RomStatus.unsupported,
              RomStatus.notFetched,
              RomStatus.localOnly,
              RomStatus.error,
            ])
              UiChip(
                label: statusLabel(s),
                selected: f.statuses.contains(s),
                onTap: () =>
                    onChanged(f.copyWith(statuses: toggleSet(f.statuses, s))),
              ),
            UiChip(
              label: 'No achievements',
              selected: f.onlyNoAchievements,
              onTap: () => onChanged(
                  f.copyWith(onlyNoAchievements: !f.onlyNoAchievements)),
            ),
          ]),
          if (showProgress) ...[
            const SizedBox(height: 8),
            _section(context, 'Progress', [
              for (final ps in ProgressState.values)
                UiChip(
                  label: progressLabel(ps),
                  selected: f.progressStates.contains(ps),
                  onTap: () => onChanged(f.copyWith(
                      progressStates: toggleSet(f.progressStates, ps))),
                ),
              UiChip(
                label: 'Recently played',
                selected: f.onlyRecentlyPlayed,
                onTap: () => onChanged(
                    f.copyWith(onlyRecentlyPlayed: !f.onlyRecentlyPlayed)),
              ),
            ]),
          ],
          if (availableGenres.isNotEmpty) ...[
            const SizedBox(height: 8),
            _section(context, 'Genre', [
              for (final g in availableGenres)
                UiChip(
                  label: g,
                  selected: f.genres.contains(g),
                  onTap: () =>
                      onChanged(f.copyWith(genres: toggleSet(f.genres, g))),
                ),
            ]),
          ],
          if (availableTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _section(context, 'Tags', [
              for (final t in availableTags)
                UiChip(
                  label: t,
                  selected: f.tags.contains(t),
                  onTap: () =>
                      onChanged(f.copyWith(tags: toggleSet(f.tags, t))),
                ),
            ]),
          ],
          if (playlists.isNotEmpty) ...[
            const SizedBox(height: 8),
            _section(context, 'Playlists', [
              for (final pl in playlists)
                UiDropdown<String>(
                  value: _playlistMode(pl.id),
                  items: [
                    (value: 'all', label: '${pl.name}: show all'),
                    (value: 'only', label: '${pl.name}: only'),
                    (value: 'exclude', label: '${pl.name}: exclude'),
                  ],
                  onChanged: (mode) {
                    final inc = {...f.includePlaylistIds}..remove(pl.id);
                    final exc = {...f.excludePlaylistIds}..remove(pl.id);
                    if (mode == 'only') inc.add(pl.id);
                    if (mode == 'exclude') exc.add(pl.id);
                    onChanged(f.copyWith(
                        includePlaylistIds: inc, excludePlaylistIds: exc));
                  },
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> chips) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: ui.labelCaps.copyWith(color: ui.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
