import 'dart:io';

import 'package:flutter/material.dart';

import '../services/console_map.dart';
import '../services/emulator_catalog.dart';
import '../services/emulator_store.dart';
import 'pick_emulator.dart';
import 'ui/ui_focusable.dart';

/// Connect an emulator to [consoleId] on the spot. True when set (caller
/// retries the launch), false on cancel.
Future<bool> showSetEmulatorDialog(
    BuildContext context, int consoleId) async {
  final name = ConsoleMap.nameFor(consoleId) ?? 'this system';
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _SetEmulatorDialog(consoleId: consoleId, consoleName: name),
  );
  return result ?? false;
}

class _SetEmulatorDialog extends StatefulWidget {
  final int consoleId;
  final String consoleName;
  const _SetEmulatorDialog(
      {required this.consoleId, required this.consoleName});

  @override
  State<_SetEmulatorDialog> createState() => _SetEmulatorDialogState();
}

class _SetEmulatorDialogState extends State<_SetEmulatorDialog> {
  List<Emulator> _emulators = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await EmulatorStore.emulators();
    if (!mounted) return;
    setState(() {
      _emulators = list;
      _loading = false;
    });
  }

  // Connects [emu] to this console and closes with success. Desktop gets the
  // catalog's default launch args; Android launches via intent (args unused).
  Future<void> _connect(Emulator emu) async {
    final args = Platform.isAndroid
        ? ''
        : EmulatorCatalog.defaultArgsFor(
                widget.consoleId, emu.kindId, emu.exePath) ??
            '"{file.path}"';
    await EmulatorStore.setConnection(widget.consoleId, emu.id, args);
    if (mounted) Navigator.pop(context, true);
  }

  // Adds a new emulator, then connects it. Android picks an installed app;
  // desktop browses for an exe.
  Future<void> _add() async {
    setState(() => _busy = true);
    final emu = await pickNewEmulator(context);
    if (emu == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await EmulatorStore.addEmulator(emu);
    await _connect(emu);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set emulator for ${widget.consoleName}'),
      content: _loading
          ? const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_emulators.isEmpty)
                  Text(Platform.isAndroid
                      ? 'No emulators added yet. Pick an installed app below. '
                          'This system will use it for every game in the folder.'
                      : 'No emulators added yet. Browse for one below. This '
                          'system will use it for every game in the folder.')
                else ...[
                  const Text('Pick one of your emulators:'),
                  const SizedBox(height: 8),
                  for (final emu in _emulators)
                    UiFocusZoom(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.videogame_asset),
                        title: Text(emu.name),
                        subtitle: Text(emu.exePath,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: _busy ? null : () => _connect(emu),
                      ),
                    ),
                ],
              ],
            ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ),
        UiFocusZoom(
          child: FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(Platform.isAndroid ? 'Pick app…' : 'Browse exe…'),
          ),
        ),
      ],
    );
  }
}
