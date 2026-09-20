import 'package:flutter/material.dart';

import '../services/data_wipe.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_focusable.dart';

/// One tickable line in the dialog: what it deletes and what that costs.
typedef _Row = ({ClearTarget target, String label, String cost});

/// Ordered worst-to-cheapest, so the irreversible choices are read first and
/// the pure caches (which only cost a re-download) sit at the bottom.
const _rows = <_Row>[
  (
    target: ClearTarget.scans,
    label: 'Scan results',
    cost: 'Every hash, match and achievement count. Your whole library has '
        'to be re-scanned.',
  ),
  (
    target: ClearTarget.playlists,
    label: 'Playlists and favorite systems',
    cost: 'Favorites, Played, Trash and anything you made yourself. Cull '
        'verdicts go with them, because that is where the deck files them.',
  ),
  (
    target: ClearTarget.cullVerdicts,
    label: 'Cull verdicts',
    cost: 'Which games the elimination game has judged. They come back into '
        'the deck; playlists keep whatever the verdicts put there.',
  ),
  (
    target: ClearTarget.scrapedData,
    label: 'Imported scraped data',
    cost: 'Box art and descriptions from gamelist.xml. Re-importable from '
        'the same folder.',
  ),
  (
    target: ClearTarget.raData,
    label: 'Downloaded RetroAchievements data',
    cost: 'Cached game lists. Re-downloaded on the next fetch, so clear this '
        'if matches look wrong.',
  ),
  (
    target: ClearTarget.artwork,
    label: 'Cached artwork',
    cost: 'Covers and achievement icons. Re-downloaded on demand;',
  ),
];

/// The width-capped body, so a test can measure what the cap actually does
/// (the AlertDialog itself lays out larger than the surface it paints).
const clearDataContentKey = Key('clear-data-content');

/// Lets the user pick what to delete. Returns the chosen targets, or null if
/// they cancelled. Nothing here can touch settings, the API key or ROM files.
Future<Set<ClearTarget>?> showClearDataDialog(BuildContext context) {
  return showDialog<Set<ClearTarget>>(
    context: context,
    builder: (_) => const _ClearDataDialog(),
  );
}

class _ClearDataDialog extends StatefulWidget {
  const _ClearDataDialog();

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
  // Nothing ticked to start: this dialog only deletes, so it opens unable to
  // do anything until the user says what.
  final _chosen = <ClearTarget>{};

  /// Cull verdicts follow playlists, so the row shows as ticked and locked
  /// while playlists are chosen rather than silently disagreeing with what
  /// the wipe will actually do.
  bool _forced(ClearTarget target) =>
      target == ClearTarget.cullVerdicts &&
      _chosen.contains(ClearTarget.playlists);

  void _toggle(ClearTarget target, bool? on) {
    setState(() => on == true ? _chosen.add(target) : _chosen.remove(target));
  }

  void _toggleAll(bool? on) {
    setState(() {
      _chosen.clear();
      if (on == true) _chosen.addAll(ClearTarget.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final all = _chosen.length == ClearTarget.values.length;
    return AlertDialog(
      title: const Text('Clear data'),
      // Wide enough to read the cost lines without stretching to the window:
      // maxFinite alone would run a desktop dialog the full screen width, and
      // a fixed width would overflow a phone. The cap holds the text to a
      // readable measure and the dialog shrinks below it when there's less
      // room.
      content: ConstrainedBox(
        key: clearDataContentKey,
        constraints: const BoxConstraints(maxWidth: 520),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pick what to delete. Your ROM files, your settings and your '
                  'RetroAchievements login are never touched.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: ui.muted),
                ),
                const SizedBox(height: 8),
                UiFocusZoom(
                  child: CheckboxListTile(
                    value: all,
                    tristate: true,
                    onChanged: _toggleAll,
                    title: const Text('Everything'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
                Divider(height: 1, thickness: ui.borderWidth, color: ui.border),
                for (final row in _rows)
                  UiFocusZoom(
                    child: CheckboxListTile(
                      value: _forced(row.target) || _chosen.contains(row.target),
                      onChanged: _forced(row.target)
                          ? null
                          : (v) => _toggle(row.target, v),
                      title: Text(row.label),
                      subtitle: Text(row.cost,
                          style: TextStyle(fontSize: 12, color: ui.muted)),
                      controlAffinity: ListTileControlAffinity.leading,
                      isThreeLine: true,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: _chosen.isEmpty
                ? null
                : () => Navigator.pop(context, expandTargets(_chosen)),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ),
      ],
    );
  }
}
