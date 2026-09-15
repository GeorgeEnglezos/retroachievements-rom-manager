import 'package:flutter/material.dart';

import '../../models/rom_result.dart';
import '../../services/playlist_store.dart';
import '../../theme/ui_tokens.dart';
import '../rom_grid_item.dart';

// The tile's text block under the art (title + meta line): art height plus this
// is the tile's total height. Kept in step with GameCover's lean text block,
// with a little slack so font metrics never tip it into an overflow.
const double _tileTextHeight = 66;

// A row shows at most this many games; extra ones aren't worth a second screen
// of scrolling for a "top picks" shelf. When fewer tiles than fit the width are
// shown, the spare width grows the tiles instead (see _effectiveTileSize) rather
// than leaving it blank or raising this cap.
const int _maxTiles = 10;

// Horizontal space one tile actually occupies beyond its art: CoverTile's own
// padding (8 each side) plus the strip's padding (8 each side).
const double _tileHorizontalChrome = 32;

// Tiles never grow past this multiple of the caller's tileSize, so a row with
// only one or two games doesn't blow its art up to fill the whole width.
const double _maxGrowth = 1.5;

// Clips a strip's leading/trailing tile at the row's true left/right edges
// while leaving top/bottom wide open, so a focus-scaled tile still pops
// vertically but can't bleed sideways into whatever sits beside the row.
class _HorizontalOnlyClip extends CustomClipper<Rect> {
  const _HorizontalOnlyClip();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -1000, size.width, size.height + 1000);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}

/// A titled row of game tiles for the couch UI. Focusing a tile (D-pad/stick or
/// keyboard) grows it and slides it toward centre; A on a focused tile fires
/// [onOpen]. Renders nothing when [games] is empty so a home screen can list
/// several rows and only the filled ones show.
///
/// Tiles start at [tileSize] and the row scrolls horizontally: a narrower
/// window hides the overflow behind the scroll rather than shrinking the art.
/// A wider window that has room to spare grows the tiles to fill it (capped at
/// [_maxGrowth]x) instead of leaving a blank strip or adding an 11th game —
/// except in [compact], the fitted home layout that stacks three rows on one
/// screen sharing one height budget, where [tileSize] is already final (see
/// CouchHome.couchFillTileSize) and growing it further per-row would break
/// that shared budget.
class CoverRow extends StatelessWidget {
  final String title;
  final List<RomResult> games;
  final void Function(RomResult rom) onOpen;
  final double tileSize;
  final bool compact;

  const CoverRow({
    super.key,
    required this.title,
    required this.games,
    required this.onOpen,
    this.tileSize = 160,
    this.compact = false,
  });

  // Extra space above/below the strip so tiles can scale past their cell
  // bounds without the ListView clipping the zoom. Subtracted from the
  // enclosing SizedBox so overall row height is unchanged.
  static const double _overflowPad = 12.0;

  // The size tiles actually render at: [tileSize] unless the row has more
  // width than the capped tile count needs, in which case it grows to fill
  // that width (capped at _maxGrowth) instead of leaving it blank. Skipped in
  // [compact] (the fitted desktop layout): there, [tileSize] already comes
  // from couchFillTileSize sized to fill the *shared* height budget across
  // every row, and growing it again here per-row would blow past that budget
  // and make rows with fewer games render bigger than the others.
  double _effectiveTileSize(double maxWidth) {
    if (compact) return tileSize;
    final count = _maxTiles.clamp(1, games.length);
    final natural = count * (tileSize + _tileHorizontalChrome);
    if (maxWidth <= natural) return tileSize;
    final grown = maxWidth / count - _tileHorizontalChrome;
    return grown.clamp(tileSize, tileSize * _maxGrowth);
  }

  Widget _strip(double size) {
    final count = _maxTiles.clamp(1, games.length);
    return ClipRect(
      // Clip only left/right, at the row's own bounds: the focused-tile scale
      // still pops freely above/below (the ListView itself stays unclipped),
      // but the leading/trailing tile can no longer bleed sideways over
      // whatever sits next to the row (e.g. the nav sidebar).
      clipper: const _HorizontalOnlyClip(),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: _overflowPad),
        itemCount: count,
        itemBuilder: (_, i) => CoverTile(
          rom: games[i],
          size: size,
          onOpen: () => onOpen(games[i]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();
    final ui = context.ui;
    return LayoutBuilder(
      builder: (context, c) {
        final size = _effectiveTileSize(c.maxWidth);
        return Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(8, compact ? 6 : 24, 8, compact ? 6 : 12),
              child: Text(title,
                  style: ui.display.copyWith(fontSize: compact ? 16 : 20)),
            ),
            // Extra _overflowPad on each side of the strip gives the tiles
            // room to scale past their cell edge without being clipped; the
            // SizedBox height absorbs the extra space so other rows don't shift.
            SizedBox(
              height: size + _tileTextHeight + _overflowPad * 2,
              child: _strip(size),
            ),
          ],
        );
      },
    );
  }
}

/// One focusable game tile: the shared [RomGridItem] (same art, numbers and
/// console line the dashboard shows) inside a controller focus ring. Focusing it
/// grows it and slides it toward centre (in a scrolling row); A/tap fires
/// [onOpen]. Shared by [CoverRow] and the couch Library grid.
class CoverTile extends StatefulWidget {
  final RomResult rom;
  final double size;
  final VoidCallback onOpen;

  const CoverTile(
      {super.key, required this.rom, required this.size, required this.onOpen});

  @override
  State<CoverTile> createState() => _CoverTileState();
}

class _CoverTileState extends State<CoverTile> {
  final _node = FocusNode();
  final _store = PlaylistStore();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    final f = _node.hasFocus;
    // Slide the focused tile to the middle of the row, the couch scroll feel.
    // A no-op in a non-scrolling row (no scrollable ancestor to move).
    if (f) {
      Scrollable.ensureVisible(context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
    if (f != _focused) setState(() => _focused = f);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: FocusableActionDetector(
        focusNode: _node,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onOpen();
            return null;
          }),
        },
        child: AnimatedScale(
          scale: _focused ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            // Focus ring painted over the tile edge so it never shifts layout.
            foregroundDecoration: BoxDecoration(
              borderRadius: ui.roundMd,
              border: Border.all(
                color: _focused ? ui.accent : Colors.transparent,
                width: 3,
              ),
            ),
            child: RomGridItem(
              rom: widget.rom,
              store: _store,
              lean: true,
              raName: true,
              width: widget.size,
              height: widget.size,
              onOpen: widget.onOpen,
            ),
          ),
        ),
      ),
    );
  }
}
