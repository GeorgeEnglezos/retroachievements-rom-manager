import 'package:flutter/material.dart';

import '../../models/rom_result.dart';
import '../../services/home_dashboard.dart';
import '../unlock_history.dart';
import 'couch_hero.dart';
import 'couch_shelves.dart';
import 'cover_row.dart';

// Fixed cover size on Home, so tiles look the same on every screen and the count
// per row scales with width. ponytail: one number; tune here if a denser or
// larger shelf is wanted.
const double _couchTileSize = 118;

/// The big-picture home: the two featured banners (closest to beat + mastery)
/// across the top, then the "jump back in / closest to mastery / popular &
/// unplayed" cover rows filling the left, with the recent-unlocks panel beside
/// them on the right (starting at the rows, not the banners). Everything fits on
/// one screen: nothing here scrolls, each area renders only what fits. Stateless;
/// the shell owns the data load and the open action.
class CouchHome extends StatelessWidget {
  final HomeDashboard dashboard;
  final void Function(RomResult rom) onOpen;

  const CouchHome({super.key, required this.dashboard, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (!dashboard.hasContent) {
      return const CouchEmpty(message: 'Your library fills up as you play.');
    }
    final spotlight = dashboard.spotlight;
    final beat = dashboard.beatSpotlight;
    return LayoutBuilder(builder: (context, c) {
      // The fixed one-screen layout needs room for two side-by-side banners plus
      // three cover rows. A phone or a short window can't fit that, so there we
      // fall back to a vertically scrolling stack with scrolling rows.
      final compact = c.maxWidth < 720 || c.maxHeight < 560;
      return compact ? _compact(spotlight, beat) : _fitted(spotlight, beat);
    });
  }

  /// The desktop/TV layout: banners across the top, cover rows filling the left,
  /// the recent-unlocks panel beside them. Everything sits on one screen; nothing
  /// scrolls, each area renders only what fits.
  Widget _fitted(RomResult? spotlight, RomResult? beat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spotlight != null) ...[
            _heroes(spotlight, beat),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rows take three quarters, the unlocks panel the last quarter,
                // so the panel absorbs the row's trailing whole-tile space.
                Expanded(flex: 3, child: _fillRows()),
                const SizedBox(width: 16),
                const Expanded(child: UnlockHistory(fillHeight: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The phone/short-window layout: the two banners side by side, each cover row
  /// a fixed height that scrolls horizontally, the unlocks panel below. The whole
  /// thing
  /// scrolls vertically so nothing is stuck off-screen.
  Widget _compact(RomResult? spotlight, RomResult? beat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spotlight != null) ...[
            _heroes(spotlight, beat),
            const SizedBox(height: 12),
          ],
          for (final (title, games) in _rowData())
            CoverRow(
              title: title,
              games: games,
              onOpen: onOpen,
              tileSize: _couchTileSize,
            ),
          const SizedBox(height: 16),
          const SizedBox(height: 300, child: UnlockHistory(fillHeight: true)),
        ],
      ),
    );
  }

  /// The non-empty cover-row buckets, in display order. Empty buckets are dropped
  /// so a sparse library doesn't leave labelled blanks.
  List<(String, List<RomResult>)> _rowData() => <(String, List<RomResult>)>[
        ('Jump back in', dashboard.continuePlaying),
        ('Closest to mastery', dashboard.closestToMastery),
        ('Popular & unplayed', dashboard.popularUnplayed),
      ].where((r) => r.$2.isNotEmpty).toList();

  /// The fitted layout's rows, packed compactly at the top at a fixed tile size.
  /// Tiles keep [_couchTileSize] on every screen; a narrower window scrolls each
  /// row horizontally rather than shrinking the art. The column scrolls
  /// vertically if the three rows don't fit a short window.
  Widget _fillRows() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, games) in _rowData())
            CoverRow(
              title: title,
              games: games,
              onOpen: onOpen,
              compact: true,
              tileSize: _couchTileSize,
            ),
        ],
      ),
    );
  }

  /// The two featured banners: "closest to beat" left, mastery right (the
  /// wireframe's COMPLETE / MASTERY). A library with no beat target shows the
  /// mastery banner alone.
  Widget _heroes(RomResult spotlight, RomResult? beat) {
    final mastery = CouchHero(
      rom: spotlight,
      eyebrow: 'MASTERY',
      autofocus: beat == null,
      onOpen: () => onOpen(spotlight),
    );
    if (beat == null) return mastery;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: CouchHero(
            rom: beat,
            eyebrow: 'CLOSEST TO BEAT',
            autofocus: true,
            onOpen: () => onOpen(beat),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: mastery),
      ],
    );
  }
}
