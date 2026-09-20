import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/folder_stats.dart';
import '../models/home_index.dart';
import '../services/console_map.dart';
import '../services/emulator_catalog.dart';
import '../services/emulator_store.dart';
import '../services/library.dart';
import '../services/scan_settings.dart';
import '../services/settings_bus.dart';
import '../theme/ui_theme.dart';
import '../theme/ui_tokens.dart';
import 'emulator_settings_section.dart';
import 'folder_card.dart' show ConsoleLogo;
import 'ui/auto_save_field.dart';
import 'ui/ui_badge.dart';
import 'ui/ui_card.dart';
import 'ui/ui_collapsible_card.dart';

/// One row of the Systems tab: a library subfolder, the console it hashes as,
/// and the emulator that runs it. Folder-keyed, because the folder is what the
/// user actually sees on disk; [consoleId] is what everything downstream keys.
class _SystemRow {
  final String folder;

  /// From the folder name alone, ignoring any override.
  final int? detected;

  /// The explicit override, or null when the folder is on auto-detect.
  final int? override;

  /// The scan row this card was built from.
  final SystemSummary summary;

  _SystemRow({
    required this.folder,
    required this.detected,
    required this.override,
    required this.summary,
  });

  int? get consoleId => override ?? detected;
}

class _SystemsData {
  final List<_SystemRow> rows;
  final List<Emulator> emulators;
  final Map<int, EmulatorConnection> connections;

  /// Console ids claimed by more than one folder. Those folders share a single
  /// emulator connection, which the card says out loud.
  final Set<int> sharedConsoleIds;

  _SystemsData(
    this.rows,
    this.emulators,
    this.connections,
    this.sharedConsoleIds,
  );
}

/// The Systems tab: every library subfolder, its console mapping and its
/// emulator connection in one list. Deliberately the only per-system list in
/// Settings, so it cannot drift out of step with a second one.
class SystemSettingsSection extends StatefulWidget {
  final Library? library; // injectable for tests

  const SystemSettingsSection({super.key, this.library});

  @override
  State<SystemSettingsSection> createState() => _SystemSettingsSectionState();
}

class _SystemSettingsSectionState extends State<SystemSettingsSection> {
  _SystemsData? _data;

  /// Console id -> name, hashable systems first, then the display-only ones.
  /// Built once: it never changes at runtime.
  static final List<MapEntry<int, String>> _consoleItems = [
    ...ConsoleMap.consoleNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)),
    ...ConsoleMap.displayNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)),
  ];

  @override
  void initState() {
    super.initState();
    settingsChanged.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    settingsChanged.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _data = data);
  }

  Future<_SystemsData> _load() async {
    final overrides = await ScanSettings.folderConsoleOverrides();

    // Library.summaries() is the app-wide source of truth for which systems
    // exist (see home_screen's grid): ignored, missing, out-of-root and empty
    // systems are already dropped there, so this list shows exactly what the
    // rest of the app shows. Never listing the root directly is the point: a
    // second listing is what let this tab and the old emulation tab disagree.
    final summaries = await (widget.library ?? Library.instance).summaries();
    final rows = [
      for (final s in summaries)
        _SystemRow(
          folder: p.basename(s.systemPath),
          detected: ConsoleMap.idForFolder(p.basename(s.systemPath)),
          override: overrides[p.basename(s.systemPath)],
          summary: s,
        ),
    ]..sort((a, b) => a.folder.toLowerCase().compareTo(b.folder.toLowerCase()));

    final counts = <int, int>{};
    for (final r in rows) {
      final id = r.consoleId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }

    return _SystemsData(
      rows,
      await EmulatorStore.emulators(),
      await EmulatorStore.connections(),
      {
        for (final e in counts.entries)
          if (e.value > 1) e.key,
      },
    );
  }

  Future<void> _setConsole(String folder, int? value) async {
    await ScanSettings.setFolderConsoleOverride(folder, value);
    await _refresh();
  }

  Future<void> _setEmulator(int consoleId, String? emulatorId) async {
    if (emulatorId == null) {
      await EmulatorStore.clearConnection(consoleId);
    } else {
      final emu = _data?.emulators.where((e) => e.id == emulatorId).firstOrNull;
      if (emu == null) return;
      // The catalog knows the right core/flags for the pairs it covers;
      // anything else just gets the ROM path.
      final args =
          EmulatorCatalog.defaultArgsFor(consoleId, emu.kindId, emu.exePath) ??
          '"{file.path}"';
      await EmulatorStore.setConnection(consoleId, emulatorId, args);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The inventory sits above the systems it feeds: add an emulator here
        // and it drops straight into the dropdowns below.
        EmulatorSettingsSection(onChanged: _refresh),
        const SizedBox(height: 24),
        UiCollapsibleCard(
          title: 'Systems',
          description:
              'The systems in your library, the same ones Home shows. The '
              'console decides how a ROM is hashed and matched, so a wrong '
              'guess means no achievements; disc systems (PS1, PSP, Saturn, …) '
              'must be set, then re-scan. The emulator is what Play launches.',
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
              else if (data.rows.isEmpty)
                Text(
                  'No scanned systems yet. Pick a library folder under General and '
                  'scan it from Home, then come back to map its consoles.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Two cards side by side once each still clears ~380px; the
                    // dropdowns and the args field need that width to stay readable.
                    final columns = constraints.maxWidth >= 800 ? 2 : 1;
                    const gap = 16.0;
                    final width =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final row in data.rows)
                          SizedBox(
                            width: width,
                            child: _SystemCard(
                              key: ValueKey(row.folder),
                              row: row,
                              emulators: data.emulators,
                              connection: row.consoleId == null
                                  ? null
                                  : data.connections[row.consoleId],
                              shared: data.sharedConsoleIds.contains(
                                row.consoleId,
                              ),
                              consoleItems: _consoleItems,
                              onConsoleChanged: (v) =>
                                  _setConsole(row.folder, v),
                              onEmulatorChanged: (v) =>
                                  _setEmulator(row.consoleId!, v),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SystemCard extends StatelessWidget {
  final _SystemRow row;
  final List<Emulator> emulators;
  final EmulatorConnection? connection;
  final bool shared;
  final List<MapEntry<int, String>> consoleItems;
  final ValueChanged<int?> onConsoleChanged;
  final ValueChanged<String?> onEmulatorChanged;

  const _SystemCard({
    super.key,
    required this.row,
    required this.emulators,
    required this.connection,
    required this.shared,
    required this.consoleItems,
    required this.onConsoleChanged,
    required this.onEmulatorChanged,
  });

  String get _detectedLabel => row.detected == null
      ? 'not recognised'
      : ConsoleMap.nameFor(row.detected) ?? 'id ${row.detected}';

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final consoleId = row.consoleId;
    final s = row.summary;
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoTile(consoleId: consoleId),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (consoleId != null &&
                        !ConsoleMap.isRaSupported(consoleId))
                      UiBadge(label: 'No RetroAchievements', color: ui.muted),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.totalGames} games · ${formatBytes(s.totalSizeBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _LabelledField(
                  label: 'Console',
                  child: UiFocusZoom(
                    child: DropdownButton<int?>(
                      key: Key('console-${row.folder}'),
                      isExpanded: true,
                      isDense: true,
                      value: row.override,
                      hint: Text(
                        'Auto ($_detectedLabel)',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: onConsoleChanged,
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: UiFocusZoom(
                            child: Text(
                              'Auto-detect ($_detectedLabel)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        for (final e in consoleItems)
                          DropdownMenuItem<int?>(
                            value: e.key,
                            child: UiFocusZoom(
                              child:
                                  Text(e.value, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (consoleId == null)
                  Text(
                    'Pick a console above before connecting an emulator.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else ...[
                  _LabelledField(
                    label: 'Emulator',
                    child: emulators.isEmpty
                        ? Text(
                            'None added yet — see the Emulators tab.',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : UiFocusZoom(
                          child: DropdownButton<String?>(
                              key: Key('emulator-${row.folder}'),
                              isExpanded: true,
                              isDense: true,
                              value:
                                  emulators.any(
                                    (e) => e.id == connection?.emulatorId,
                                  )
                                  ? connection!.emulatorId
                                  : null,
                              hint: const Text('Not set'),
                              onChanged: onEmulatorChanged,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: UiFocusZoom(child: Text('Not set')),
                                ),
                                for (final e in emulators)
                                  DropdownMenuItem<String?>(
                                    value: e.id,
                                    child: UiFocusZoom(child: Text(e.name)),
                                  ),
                              ],
                            ),
                        ),
                  ),
                  // Emulator connections are keyed by console, not by folder,
                  // so folders mapped to the same console cannot differ. Say so
                  // rather than letting one card silently change another.
                  if (shared)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Shared with the other folders on this console.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  // Args are desktop-only; Android launches via intent.
                  if (connection != null && !Platform.isAndroid)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AutoSaveTextField(
                        key: ValueKey('sysargs-$consoleId'),
                        value: connection!.args,
                        label: 'Arguments ({file.path} is the ROM)',
                        onSave: (v) => EmulatorStore.setConnection(
                          consoleId,
                          connection!.emulatorId,
                          v,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The console logo on the light backdrop full-colour logos need, in both
/// themes (same trick [ConsoleCard] uses).
class _LogoTile extends StatelessWidget {
  final int? consoleId;

  const _LogoTile({required this.consoleId});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ui.cardSurface,
        borderRadius: ui.roundSm,
        border: Border.all(color: ui.border, width: ui.borderWidth),
      ),
      child: Theme(
        data: uiTheme(UiTokens.light),
        child: ConsoleLogo(consoleId: consoleId),
      ),
    );
  }
}

/// A small caps label above its control, so the two dropdowns on a card read
/// as a form rather than two anonymous rows.
class _LabelledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabelledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ui.labelCaps.copyWith(fontSize: 10, color: ui.muted),
        ),
        child,
      ],
    );
  }
}
