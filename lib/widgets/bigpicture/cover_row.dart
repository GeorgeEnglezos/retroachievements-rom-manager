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
// of scrolling for a "top picks" shelf.
const int _maxTiles = 10;

/// A titled row of game tiles for the couch UI. Focusing a tile (D-pad/stick or
/// keyboard) grows it and slides it toward centre; A on a focused tile fires
/// [onOpen]. Renders nothing when [games] is empty so a home screen can list
/// several rows and only the filled ones show.
///
/// Tiles are always a fixed [tileSize] and the row scrolls horizontally: a
/// narrower window hides the overflow behind the scroll rather than shrinking
/// the art. [compact] only trims the title chrome and top-packs the column, for
/// the fitted home layout that stacks three rows on one screen.
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

  Widget _strip(double size) {
    final count = _maxTiles.clamp(1, games.length);
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: count,
      itemBuilder: (_, i) => CoverTile(
        rom: games[i],
        size: size,
        onOpen: () => onOpen(games[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const SizedBox.shrink();
    final ui = context.ui;
    return Column(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, compact ? 6 : 24, 8, compact ? 6 : 12),
          child: Text(title,
              style: ui.display.copyWith(fontSize: compact ? 16 : 20)),
        ),
        SizedBox(
          height: tileSize + _tileTextHeight,
          child: _strip(tileSize),
        ),
      ],
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
