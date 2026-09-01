import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/cull_deck_builder.dart';
import '../services/cull_store.dart';
import '../services/file_actions.dart';
import '../services/playlist_store.dart';
import '../theme/ui_tokens.dart';
import '../widgets/cull_card.dart';

/// The swiping view for one console: one card at a time, the next peeking
/// behind. Swipe/arrow left = trash, right = keep; favorite counts as keep.
class CullDeck extends StatefulWidget {
  final String consoleName;

  /// Every card for the console, decided ones included (see buildCullDeck).
  final List<CullCardData> allCards;

  /// Member keys already decided when the deck opened.
  final Set<String> decided;

  /// Next console with games still to decide, when the picker knows of one.
  /// Null hides the jump and means this was the last one.
  final String? nextConsoleName;

  /// Opens that next console's deck. The deck pops itself first, so the picker
  /// stays the only route underneath.
  final VoidCallback? onNextConsole;

  const CullDeck({
    super.key,
    required this.consoleName,
    required this.allCards,
    required this.decided,
    this.nextConsoleName,
    this.onNextConsole,
  });

  @override
  State<CullDeck> createState() => _CullDeckState();
}

class _CullDeckState extends State<CullDeck> {
  final CullStore _store = CullStore();
  // The deck's own copy of the console's cards: a ROM deleted mid-run is
  // removed from here so the header total and "start over" both forget it
  // instead of resurrecting a card for a file that no longer exists.
  late final List<CullCardData> _cards = [...widget.allCards];
  late final List<CullCardData> _pending = [
    for (final c in _cards)
      if (!widget.decided.contains(c.memberKey)) c
  ];
  // Cards decided in this deck, newest last, each with the in-flight store
  // write that will report the playlist keys the verdict actually added.
  // Per-deck and session-only, so undo can never reach a verdict made in
  // another console's run; the added keys keep it from taking back a
  // Trash/Favorites membership that predates the swipe.
  final List<(CullCardData, CullVerdict, Future<Set<String>>)> _history = [];

  bool get _canUndo => _history.isNotEmpty;
  int get _total => _cards.length;
  int get _done => _total - _pending.length;

  Future<void> _decide(CullVerdict verdict) async {
    if (_pending.isEmpty) return;
    final card = _pending.removeAt(0);
    // The entry goes in as the card leaves, so undo lights up with the swipe.
    // It holds the write itself rather than its result: undo awaits it, which
    // both gets the keys this verdict added and keeps the two writes in order
    // if the button is hit before the store has finished.
    final decided =
        _store.decide(card.memberKey, verdict, trashKeys: card.memberKeys);
    setState(() => _history.add((card, verdict, decided)));
    await decided;
  }

  // A ROM deleted from within the detail dialog: drop that card from the deck
  // without recording a verdict, so it never touches the decided set or the
  // undo history. Keyed rather than positional because the dialog fires once
  // per disc and stays open for the rest, so repeat calls for a card that has
  // already gone must not eat the next, never-shown card.
  void _drop(String memberKey) {
    if (!_pending.any((c) => c.memberKey == memberKey)) return;
    setState(() {
      _pending.removeWhere((c) => c.memberKey == memberKey);
      _cards.removeWhere((c) => c.memberKey == memberKey);
    });
  }

  Future<void> _undo() async {
    if (_history.isEmpty) return;
    final (card, verdict, decided) = _history.removeLast();
    setState(() => _pending.insert(0, card));
    await _store.undecide(card.memberKey, verdict, addedKeys: await decided);
  }

  Future<void> _startOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: Text(
            'Forget all ${widget.consoleName} decisions and rebuild the deck? '
            'Trashed games stay in the Trash playlist.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start over')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.resetConsole([for (final c in _cards) c.memberKey]);
    if (!mounted) return;
    setState(() {
      _history.clear();
      _pending
        ..clear()
        ..addAll(_cards);
    });
  }

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await FileActions.openUrl(url)) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't open browser")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Scaffold(
      backgroundColor: ui.background,
      appBar: AppBar(
        title: Text('${widget.consoleName} · $_done / $_total'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Start over for this console',
            onPressed: _startOver,
          ),
        ],
      ),
      body: _pending.isEmpty ? _empty(ui) : _deck(ui),
    );
  }

  // Finishing a console offers the next one as the main action; starting this
  // one over stays available underneath (and in the app bar).
  Widget _empty(UiTokens ui) {
    final next = widget.nextConsoleName;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('All ${widget.consoleName} games decided.',
              style: ui.display.copyWith(fontSize: 16)),
          if (next == null) ...[
            const SizedBox(height: 4),
            Text('Every console is done.',
                style: ui.body.copyWith(color: ui.muted)),
          ],
          const SizedBox(height: 12),
          if (next != null)
            FilledButton.icon(
              icon: const Icon(Icons.skip_next),
              label: Text('Next: $next'),
              onPressed: widget.onNextConsole,
            ),
          // Undo lives with the verdict buttons, which are gone once the deck
          // empties, so the finished screen keeps its own way back to the last
          // card.
          TextButton.icon(
            icon: const Icon(Icons.undo),
            label: const Text('Undo last card'),
            onPressed: _canUndo ? _undo : null,
          ),
          TextButton(onPressed: _startOver, child: const Text('Start over')),
        ],
      ),
    );
  }

  Widget _deck(UiTokens ui) {
    final top = _pending.first;
    final next = _pending.length > 1 ? _pending[1] : null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _decide(CullVerdict.trash),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _decide(CullVerdict.keep),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Center(
                  child: ConstrainedBox(
                    // Desktop widths give the card most of the window so the
                    // cover, the rest of the image set and the achievement
                    // readout all get room; phones keep the single-cover card,
                    // where the cap is wider than the screen anyway.
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width >= 900
                            ? 1320
                            : 520),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (next != null)
                          Transform.scale(
                            scale: 0.95,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: 0.5,
                                child: CullCard(
                                  card: next,
                                  onSearch: () {},
                                ),
                              ),
                            ),
                          ),
                        Dismissible(
                          key: ValueKey(top.memberKey),
                          // Left-to-right reveal: keep (green).
                          background: _reveal(ui, Icons.check, ui.supported,
                              Alignment.centerLeft),
                          // Right-to-left reveal: trash (red).
                          secondaryBackground: _reveal(ui, Icons.delete,
                              kDangerColor, Alignment.centerRight),
                          onDismissed: (dir) => _decide(
                              dir == DismissDirection.startToEnd
                                  ? CullVerdict.keep
                                  : CullVerdict.trash),
                          child: CullCard(
                            card: top,
                            onSearch: () => _openUrl(
                                FileActions.googleSearchUrl(top.rom.filePath)),
                            onDeleted: () => _drop(top.memberKey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buttons(ui, top),
          ],
        ),
      ),
    );
  }

  Widget _reveal(
          UiTokens ui, IconData icon, Color color, Alignment align) =>
      Container(
        decoration: BoxDecoration(color: color, borderRadius: ui.roundLg),
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(icon, color: ui.navSelectedFg, size: 36),
      );

  // Desktop/mouse path for the two swipe verdicts, with favorite (which also
  // counts as a keep) sitting between them and undo on the far left. Wrapped
  // rather than a Row so the four buttons fold to a second line on a phone
  // instead of overflowing.
  Widget _buttons(UiTokens ui, CullCardData top) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.undo),
                label: const Text('UNDO'),
                onPressed: _canUndo ? _undo : null,
              ),
              OutlinedButton.icon(
                icon: Icon(Icons.delete, color: kDangerColor),
                label: const Text('TRASH'),
                style: OutlinedButton.styleFrom(foregroundColor: kDangerColor),
                onPressed: () => _decide(CullVerdict.trash),
              ),
              OutlinedButton.icon(
                icon: Icon(
                  PlaylistStore().isFavorite(top.memberKey)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: kFavoriteColor,
                ),
                label: const Text('FAVORITE'),
                style: OutlinedButton.styleFrom(foregroundColor: kFavoriteColor),
                onPressed: () => _decide(CullVerdict.favorite),
              ),
              OutlinedButton.icon(
                icon: Icon(Icons.check, color: ui.supported),
                label: const Text('KEEP'),
                style: OutlinedButton.styleFrom(foregroundColor: ui.supported),
                onPressed: () => _decide(CullVerdict.keep),
              ),
            ],
          ),
        ),
      );
}
