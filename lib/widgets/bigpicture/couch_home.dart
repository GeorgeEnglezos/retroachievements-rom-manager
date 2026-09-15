import 'package:flutter/material.dart';

import '../../models/rom_result.dart';
import '../../services/home_dashboard.dart';
import '../../theme/ui_tokens.dart';
import '../unlock_history.dart';
import 'couch_hero.dart';
import 'couch_shelves.dart';
import 'cover_row.dart';

// Cover size on the compact (phone/short-window) layout, where rows scroll
// vertically so there is no fixed height to fill. The fitted layout derives its
// own size from the height instead (see [couchFillTileSize]).
const double _compactTileSize = 118;

/// The big-picture home: the two featured banners (closest to beat + mastery)
/// across the top, then the "jump back in / closest to mastery / popular &
/// unplayed" cover rows filling the left, with the recent-unlocks panel beside
/// them on the right (starting at the rows, not the banners). Everything fits on
/// one screen: nothing here scrolls, each area renders only what fits. Stateless;
/// the shell owns the data load and the open action.
class CouchHome extends StatelessWidget {
  final HomeDashboard dashboard;
  final void Function(RomResult rom) onOpen;
  // Right-click / long-press on a hero banner: dismiss that game so the next
  // candidate takes its place there.
  final void Function(RomResult rom) onIgnore;

  const CouchHome({
    super.key,
    required this.dashboard,
    required this.onOpen,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    if (!dashboard.hasContent) {
      return const CouchEmpty(message: 'Your library fills up as you play.');
    }
    final spotlight = dashboard.spotlight;
    final beat = dashboard.beatSpotlight;
    return LayoutBuilder(
      builder: (context, c) {
        // The fixed one-screen layout needs room for two side-by-side banners plus
        // three cover rows. A phone or a short window can't fit that, so there we
        // fall back to a vertically scrolling stack with scrolling rows. The width
        // gate is [kBreakWide] so the two-pane fitted layout only appears when the
        // desktop sidebar does too, never framed by the mobile bottom nav.
        final compact = c.maxWidth < kBreakWide || c.maxHeight < 560;
        return compact
            ? _compact(spotlight, beat)
            : _fitted(spotlight, beat, c.maxHeight);
      },
    );
  }

  // Per-row chrome height in the fitted layout: the row's title strip plus the
  // tile's text block and the scale-overflow padding above and below the strip.
  // ponytail: an estimate tuned to CoverRow(compact: true); if a font change
  // tips a row into an overflow, bump this (bigger number = smaller tiles).
  static const double _fittedRowChrome = 123;

  /// The square cover size the fitted layout uses so [rowCount] rows fill
  /// [height] instead of packing fixed tiles at the top and leaving a blank band
  /// on a tall screen. Clamped so a very short window still scrolls rather than
  /// shrinking art to nothing, and a very tall one doesn't blow tiles up huge.
  static double couchFillTileSize(double height, int rowCount) {
    if (rowCount <= 0) return _compactTileSize;
    final perRow = height / rowCount;
    return (perRow - _fittedRowChrome).clamp(_compactTileSize, 240.0);
  }

  /// The desktop/TV layout: banners across the top, cover rows filling the left,
  /// the recent-unlocks panel beside them. Everything sits on one screen; nothing
  /// scrolls, each area renders only what fits.
  Widget _fitted(RomResult? spotlight, RomResult? beat, double availableHeight) {
    // Grows with the window instead of a flat viewport fraction, so a tall
    // screen gives the banners real extra height rather than leaving it all to
    // the cover rows below. Floor matches the old minimum; ceiling keeps a very
    // tall window from turning the banners into most of the screen.
    final heroHeight = (availableHeight * 0.3).clamp(180.0, 340.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spotlight != null) ...[
            _heroes(spotlight, beat, height: heroHeight),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final rows = _rowData();
                final tile = couchFillTileSize(c.maxHeight, rows.length);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Rows take three quarters, the unlocks panel the last
                    // quarter, so the panel absorbs the row's trailing
                    // whole-tile space.
                    Expanded(flex: 3, child: _fillRows(rows, tile)),
                    const SizedBox(width: 16),
                    // The panel scales with the covers so a big window doesn't
                    // leave it a strip of tiny rows beside large art.
                    Expanded(
                      child: UnlockHistory(
                        fillHeight: true,
                        scale: tile / _compactTileSize,
                      ),
                    ),
                  ],
                );
              },
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
              tileSize: _compactTileSize,
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

  /// The fitted layout's rows, sized so they fill the column's height instead of
  /// packing fixed tiles at the top. Tiles grow with the window (bigger art on a
  /// TV, smaller on a laptop); each row still scrolls horizontally if a narrow
  /// window can't fit its covers, and the column scrolls vertically only when a
  /// short window forces the tiles to their minimum.
  Widget _fillRows(List<(String, List<RomResult>)> rows, double tile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (title, games) in rows)
            CoverRow(
              title: title,
              games: games,
              onOpen: onOpen,
              compact: true,
              tileSize: tile,
            ),
        ],
      ),
    );
  }

  /// The two featured banners: "closest to beat" left, mastery right (the
  /// wireframe's COMPLETE / MASTERY). A library with no beat target shows the
  /// mastery banner alone.
  Widget _heroes(RomResult spotlight, RomResult? beat, {double? height}) {
    final mastery = CouchHero(
      rom: spotlight,
      eyebrow: 'MASTERY',
      autofocus: beat == null,
      onOpen: () => onOpen(spotlight),
      onIgnore: () => onIgnore(spotlight),
      height: height,
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
            onIgnore: () => onIgnore(beat),
            height: height,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: mastery),
      ],
    );
  }
}
