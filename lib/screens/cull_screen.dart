import 'dart:async';

import 'package:flutter/material.dart';

import '../services/console_image.dart';
import '../services/cull_deck_builder.dart';
import '../services/cull_store.dart';
import '../services/library.dart';
import '../services/playlist_store.dart';
import '../services/settings_bus.dart';
import '../theme/ui_tokens.dart';
import '../widgets/ui/ui_card.dart';
import '../widgets/ui/ui_progress_bar.dart';
import 'cull_deck.dart';

/// Elimination-game entry point: pick a console, see decided/total progress,
/// tap to swipe through its deck.
class CullScreen extends StatefulWidget {
  // Injectable for tests; defaults to the shared instance.
  final Library? library;

  const CullScreen({super.key, this.library});

  @override
  State<CullScreen> createState() => _CullScreenState();
}

class _CullRowData {
  final String name;
  final int? consoleId;
  final List<CullCardData> cards;
  final int done;
  // Row identity: folder names can repeat across library roots, and a reload
  // rebuilds these objects, so neither the name nor the instance is stable.
  final String systemPath;
  const _CullRowData(
      this.name, this.systemPath, this.consoleId, this.cards, this.done);
}

class _CullScreenState extends State<CullScreen> {
  late final Library _lib = widget.library ?? Library.instance;
  List<_CullRowData>? _rows;
  Timer? _reloadTimer;
  // Bumped per run so a slower earlier reload can't overwrite a newer one.
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-read after a scan writes new summaries (same pattern as StorageScreen).
    _lib.addListener(_scheduleLoad);
    settingsChanged.addListener(_scheduleLoad);
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _lib.removeListener(_scheduleLoad);
    settingsChanged.removeListener(_scheduleLoad);
    super.dispose();
  }

  // A scan saves once per system, and this screen sits in the shell's
  // IndexedStack, so the notifications arrive in a burst while the user is on
  // another tab. Rebuilding every deck that often is wasted work, so coalesce
  // the burst into one reload.
  void _scheduleLoad() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final id = ++_loadId;
    // Populate the playlist store before any card renders, or every heart
    // shows empty until something else happens to load it.
    await PlaylistStore().all();
    final summaries = await _lib.summaries();
    final decided = await CullStore().decided();
    final rows = <_CullRowData>[];
    for (final s in summaries) {
      // Excluded files and games under ignored subfolders must not become
      // cards, or the totals here drift from the home grid.
      final games = await _lib.gamesFor(s.systemPath);
      if (games.isEmpty) continue;
      final cards =
          buildCullDeck(games, consoleId: s.consoleId, consoleName: s.name);
      final done = cards.where((c) => decided.contains(c.memberKey)).length;
      rows.add(_CullRowData(s.name, s.systemPath, s.consoleId, cards, done));
    }
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted || id != _loadId) return;
    setState(() => _rows = rows);
  }

  // The console after [systemPath] that still has cards to decide, wrapping
  // around the list. Null when it is the only one left with work.
  _CullRowData? _nextWithWork(String systemPath) {
    final rows = _rows ?? const <_CullRowData>[];
    final start = rows.indexWhere((r) => r.systemPath == systemPath);
    if (start < 0) return null;
    for (var i = 1; i <= rows.length; i++) {
      final r = rows[(start + i) % rows.length];
      if (r.systemPath != systemPath && r.done < r.cards.length) return r;
    }
    return null;
  }

  Future<void> _open(_CullRowData row) async {
    // Reload first: the row on screen can predate the run the user just
    // finished, and the next-console suggestion has to reflect the current
    // counts.
    await _load();
    final decided = await CullStore().decided();
    if (!mounted) return;
    final fresh = (_rows ?? const <_CullRowData>[])
        .where((r) => r.systemPath == row.systemPath)
        .firstOrNull ??
        row;
    final next = _nextWithWork(fresh.systemPath);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CullDeck(
        consoleName: fresh.name,
        allCards: fresh.cards,
        decided: decided,
        nextConsoleName: next?.name,
        onNextConsole: next == null
            ? null
            : () {
                Navigator.of(context).pop();
                _open(next);
              },
      ),
    ));
    _load(); // refresh counts after the run
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (rows.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text('No scanned systems yet. Scan your library first.',
                textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          return _CullConsoleRow(row: row, onTap: () => _open(row));
        },
      ),
    );
  }
}

/// One console row: logo, name, decided/total progress bar.
class _CullConsoleRow extends StatelessWidget {
  final _CullRowData row;
  final VoidCallback onTap;
  const _CullConsoleRow({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final total = row.cards.length;
    final complete = total > 0 && row.done >= total;
    final tint = ConsoleImage.tintedLogos.contains(row.consoleId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: UiCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        flourish: FocusFlourish.jump,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(
                  ConsoleImage.assetOrGeneric(row.consoleId),
                  fit: BoxFit.contain,
                  color: tint ? ui.text : null,
                  colorBlendMode: tint ? BlendMode.srcIn : null,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.videogame_asset, color: ui.muted),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(row.name,
                        style: ui.display.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${row.done} / $total decided',
                        style: ui.body.copyWith(fontSize: 12, color: ui.muted)),
                    const SizedBox(height: 4),
                    UiProgressBar(
                        value: total == 0 ? 0 : row.done / total, height: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(complete ? Icons.check_circle : Icons.chevron_right,
                  color: complete ? ui.supported : ui.muted),
            ],
          ),
        ),
      ),
    );
  }
}
