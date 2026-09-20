import 'package:flutter/material.dart';

import '../services/emulator_store.dart';
import 'ui/ui_focusable.dart';

/// Picks which of [choices] to launch one game in. Returns null on cancel.
/// Nothing is connected: the console keeps its own emulator, this is a
/// one-off. See [EmulatorStore.emulatorsForConsole] for the list.
Future<Emulator?> showPlayWithDialog(
  BuildContext context,
  List<Emulator> choices,
  String consoleName,
) =>
    showDialog<Emulator>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Play with'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emulators you added for $consoleName:'),
            const SizedBox(height: 8),
            for (final emu in choices)
              UiFocusZoom(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.videogame_asset),
                  title: Text(emu.name),
                  subtitle: Text(emu.exePath,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, emu),
                ),
              ),
          ],
        ),
        actions: [
          UiFocusZoom(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
