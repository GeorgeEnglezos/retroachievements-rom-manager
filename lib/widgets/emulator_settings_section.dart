import 'dart:io';

import 'package:flutter/material.dart';

import '../services/android_emulators.dart';
import '../services/emulator_finder.dart';
import '../services/emulator_store.dart';
import '../strings.dart';
import 'pick_emulator.dart';
import 'ui/auto_save_field.dart';
import 'ui/ui_collapsible_card.dart';
import 'ui/ui_focusable.dart';

/// The emulator inventory: the programs themselves, not what runs what. Which
/// console each one drives is picked per system on the Systems tab, which this
/// sits above, so adding an emulator and connecting it stay on one screen.
class EmulatorSettingsSection extends StatefulWidget {
  /// Called after the inventory changes, so the system rows below can reload
  /// their (now different) emulator list.
  final VoidCallback? onChanged;

  const EmulatorSettingsSection({super.key, this.onChanged});

  @override
  State<EmulatorSettingsSection> createState() =>
      _EmulatorSettingsSectionState();
}

class _EmulatorSettingsSectionState extends State<EmulatorSettingsSection> {
  _EmulatorData? _data;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // State field, not FutureBuilder: repaints reliably after a native picker.
  Future<void> _refresh() async {
    final data = await _load();
    if (!mounted) return;
    setState(() => _data = data);
    widget.onChanged?.call();
  }

  Future<_EmulatorData> _load() async {
    // Android emulators are installed apps, so the first time this tab opens we
    // sweep them in without asking. After that it's the Detect button, so a
    // removed emulator stays removed.
    if (Platform.isAndroid && await EmulatorStore.takeAndroidSweep()) {
      await _addDetectedApps();
    }
    final emulators = await EmulatorStore.emulators();
    final fullscreen = await EmulatorStore.launchFullscreen();
    return _EmulatorData(emulators, fullscreen);
  }

  Future<void> _addEmulator() async {
    final emu = await pickNewEmulator(context);
    if (emu == null) return;
    await EmulatorStore.addEmulator(emu);
    await _refresh();
    _toast(SettingsStrings.emulatorAdded(emu.name));
  }

  // Adds every installed app we recognise as an emulator, skipping kinds the
  // user already has. Returns what it added.
  Future<List<Emulator>> _addDetectedApps() async {
    final found = emulatorsFromApps(
      await AndroidEmulators.installedApps(),
      existing: await EmulatorStore.emulators(),
    );
    for (final emu in found) {
      await EmulatorStore.addEmulator(emu);
    }
    return found;
  }

  Future<void> _detectEmulatorApps() async {
    setState(() => _scanning = true);
    try {
      final found = await _addDetectedApps();
      await _refresh();
      _toast(
        found.isEmpty
            ? SettingsStrings.noNewEmulatorApps
            : SettingsStrings.emulatorsAdded(found.map((e) => e.name)),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  // Desktop: point at a folder, add every emulator under it. EmulatorStore
  // connects each one's default systems as it's added.
  Future<void> _scanForEmulators() async {
    final folder = await pickEmulatorFolder(context);
    if (folder == null) return;
    setState(() => _scanning = true);
    try {
      final found = await findEmulators(
        Directory(folder),
        existing: _data?.emulators ?? const [],
      );
      for (final emu in found) {
        await EmulatorStore.addEmulator(emu);
      }
      await _refresh();
      _toast(
        found.isEmpty
            ? SettingsStrings.noNewEmulatorsInFolder
            : SettingsStrings.emulatorsAdded(found.map((e) => e.name)),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _editEmulatorExe(Emulator emu) async {
    final picked = await pickNewEmulator(
      context,
      dialogTitle: SettingsStrings.emulatorExeDialogFor(emu.name),
    );
    if (picked == null) return;
    await EmulatorStore.updateEmulatorExe(emu.id, picked.exePath);
    await _refresh();
    _toast(SettingsStrings.emulatorUpdated(emu.name));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return UiCollapsibleCard(
      title: SettingsStrings.emulatorsTitle,
      description: Platform.isAndroid
          ? SettingsStrings.emulatorsHelpAndroid
          : SettingsStrings.emulatorsHelpDesktop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            // Fullscreen is a desktop CLI flag; hidden on Android.
            if (!Platform.isAndroid)
              UiFocusZoom(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(SettingsStrings.launchFullscreen),
                  value: data.launchFullscreen,
                  onChanged: (v) async {
                    await EmulatorStore.setLaunchFullscreen(v ?? false);
                    await _refresh();
                  },
                ),
              ),
            if (data.emulators.isEmpty)
              const Text(
                SettingsStrings.noEmulators,
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              for (final emu in data.emulators)
                Column(
                  key: ValueKey(emu.id),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiFocusZoom(
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(emu.name),
                        subtitle: Text(
                          emu.exePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: Platform.isAndroid
                                  ? SettingsStrings.changeAppTooltip
                                  : SettingsStrings.changeExeTooltip,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editEmulatorExe(emu),
                            ),
                            IconButton(
                              tooltip: SettingsStrings.removeTooltip,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await EmulatorStore.removeEmulator(emu.id);
                                await _refresh();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Args are desktop-only; Android launches via intent.
                    if (!Platform.isAndroid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AutoSaveTextField(
                          key: ValueKey('args-${emu.id}'),
                          value: emu.extraArgs,
                          label: SettingsStrings.extraArgsLabel,
                          onSave: (v) => EmulatorStore.setExtraArgs(emu.id, v),
                        ),
                      ),
                  ],
                ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                UiFocusZoom(
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : _addEmulator,
                    icon: const Icon(Icons.add),
                    label: Text(
                      Platform.isAndroid
                          ? SettingsStrings.addEmulatorApp
                          : SettingsStrings.addEmulatorExe,
                    ),
                  ),
                ),
                // Desktop searches a folder of exes; Android sweeps the
                // installed apps, so there's nothing to browse for.
                UiFocusZoom(
                  child: OutlinedButton.icon(
                    onPressed: _scanning
                        ? null
                        : Platform.isAndroid
                        ? _detectEmulatorApps
                        : _scanForEmulators,
                    icon: _scanning
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore),
                    label: Text(
                      _scanning
                          ? SettingsStrings.scanning
                          : Platform.isAndroid
                          ? SettingsStrings.detectEmulatorApps
                          : SettingsStrings.scanEmulatorFolder,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmulatorData {
  final List<Emulator> emulators;
  final bool launchFullscreen;
  _EmulatorData(this.emulators, this.launchFullscreen);
}
