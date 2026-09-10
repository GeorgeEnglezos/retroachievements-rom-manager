import 'package:flutter/material.dart';

import '../../models/folder_stats.dart' show compactCount;
import '../../models/rom_result.dart';
import '../../services/couch_rows.dart';
import '../../theme/ui_tokens.dart';
import '../folder_card.dart' show ConsoleLogo;
import '../rom_thumb.dart';
import '../ui/console_card.dart';

// The right panel lists a system's hottest few; the rest aren't worth a longer
// scroll for a "what to play next" glance.
const int _maxGames = 20;

// _selected sentinel for the "All Consoles" tile (the overall top list).
const int _overallIndex = -1;

/// The Play Next tab: a grid of console folders (plus an "All Consoles" tile)
/// on the left; activating one (left-click / Enter / controller A) lists its
/// top games on the right. Games arrive already sorted (see [playNextRows]).
class ConsoleBrowser extends StatefulWidget {
  final List<CouchRow> rows;
  final CouchRow overall;
  final void Function(RomResult rom) onOpen;
  final String emptyMessage;

  const ConsoleBrowser({
    super.key,
    required this.rows,
    required this.overall,
    required this.onOpen,
    this.emptyMessage = 'Nothing here yet.',
  });

  @override
  State<ConsoleBrowser> createState() => _ConsoleBrowserState();
}

class _ConsoleBrowserState extends State<ConsoleBrowser> {
  int? _selected;

  @override
  void didUpdateWidget(ConsoleBrowser old) {
    super.didUpdateWidget(old);
    // A reload (deleted game, toggled Owned/All) can shrink the list; drop a
    // now-out-of-range console selection. The overall tile is always valid.
    if (_selected != null &&
        _selected! >= 0 &&
        _selected! >= widget.rows.length) {
      _selected = null;
    }
  }

  CouchRow? _selectedRow() {
    final sel = _selected;
    if (sel == null) return null;
    return sel == _overallIndex ? widget.overall : widget.rows[sel];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return CouchEmpty(message: widget.emptyMessage);
    final ui = context.ui;
    final row = _selectedRow();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _grid()),
        Container(width: ui.borderWidth, color: ui.border),
        Expanded(
          flex: 2,
          child: row == null
              ? _Prompt()
              : _GamesPanel(row: row, onOpen: widget.onOpen),
        ),
      ],
    );
  }

  Widget _grid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 190,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      // One extra leading tile: "All Consoles".
      itemCount: widget.rows.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _ConsoleTile(
            name: 'All Consoles',
            icon: Icons.apps,
            gameCount: widget.overall.games.length,
            selected: _selected == _overallIndex,
            onSelect: () => setState(() => _selected = _overallIndex),
          );
        }
        final idx = i - 1;
        final row = widget.rows[idx];
        return _ConsoleTile(
          name: row.title,
          consoleId: row.games.isEmpty ? null : row.games.first.consoleId,
          gameCount: row.games.length,
          selected: idx == _selected,
          onSelect: () => setState(() => _selected = idx),
        );
      },
    );
  }
}

/// One console folder in the grid. Focusable (D-pad/keyboard) and clickable;
/// Enter/A or a click selects it, drawing the accent ring the selection shows.
class _ConsoleTile extends StatefulWidget {
  final String name;
  final int? consoleId;
  // When set, shown instead of a console logo (the "All Consoles" tile).
  final IconData? icon;
  final int gameCount;
  final bool selected;
  final VoidCallback onSelect;

  const _ConsoleTile({
    required this.name,
    this.consoleId,
    this.icon,
    required this.gameCount,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_ConsoleTile> createState() => _ConsoleTileState();
}

class _ConsoleTileState extends State<_ConsoleTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final active = widget.selected || _focused;
    return FocusableActionDetector(
      onShowFocusHighlight: (f) => setState(() => _focused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onSelect();
          return null;
        }),
      },
      child: Container(
        // Transparent border always reserved so selecting never shifts layout.
        decoration: BoxDecoration(
          borderRadius: ui.roundLg,
          border: Border.all(
              color: active ? ui.accent : Colors.transparent, width: 3),
        ),
        child: ConsoleCard(
          onTap: widget.onSelect,
          padding: const EdgeInsets.all(12),
          child: Builder(
            builder: (context) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: widget.icon != null
                      ? Icon(widget.icon, size: 56, color: ui.accent)
                      : ConsoleLogo(consoleId: widget.consoleId),
                ),
                const SizedBox(height: 8),
                Text(widget.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    '${widget.gameCount} '
                    '${widget.gameCount == 1 ? 'game' : 'games'}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The right panel: the selected system's hottest games as a tappable list.
class _GamesPanel extends StatelessWidget {
  final CouchRow row;
  final void Function(RomResult rom) onOpen;

  const _GamesPanel({required this.row, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final count = _maxGames.clamp(0, row.games.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(row.title, style: ui.display.copyWith(fontSize: 20)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: count,
            itemBuilder: (_, i) => _GameRow(rom: row.games[i], onOpen: onOpen),
          ),
        ),
      ],
    );
  }
}

/// One game in the right-hand list: cover thumbnail, RA title, player count.
/// [InkWell] gives click, keyboard (Enter) and controller (A) activation.
class _GameRow extends StatelessWidget {
  final RomResult rom;
  final void Function(RomResult rom) onOpen;

  const _GameRow({required this.rom, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final players = rom.numPlayersCasual ?? 0;
    return InkWell(
      onTap: () => onOpen(rom),
      borderRadius: ui.roundMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: RomThumb(rom: rom, size: 48, raArt: rom.thumbArt),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rom.gameTitle ?? rom.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (players > 0)
                    Text('${compactCount(players)} players',
                        style: TextStyle(fontSize: 12, color: ui.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the right panel until a console is picked.
class _Prompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videogame_asset_outlined, size: 48, color: ui.muted),
            const SizedBox(height: 12),
            Text('Pick a system to see its top games',
                textAlign: TextAlign.center,
                style: TextStyle(color: ui.muted, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Shared centred message for an empty couch tab.
class CouchEmpty extends StatelessWidget {
  final String message;
  const CouchEmpty({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: ui.muted, fontSize: 16)),
      ),
    );
  }
}
