import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_theme.dart';
import '../services/backup_service.dart';
import '../services/console_map.dart';
import '../services/credentials.dart';
import '../services/display_name.dart';
import '../services/emulator_catalog.dart';
import '../services/emulator_store.dart';
import '../services/library.dart';
import '../services/pref_keys.dart';
import '../services/library_folder.dart';
import '../services/scraper/gamelist_importer.dart';
import '../services/scraper/scraped_store.dart';
import '../widgets/pick_library_folder.dart';
import '../services/scan_settings.dart';
import '../widgets/pick_emulator.dart';
import 'setup_wizard.dart';

class SettingsScreen extends StatefulWidget {
  // Injectable for tests; defaults to the shared library store.
  final Library? library;

  const SettingsScreen({super.key, this.library});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _extensionsCtrl = TextEditingController();
  final _ignoredCtrl = TextEditingController();
  final _excludedCtrl = TextEditingController();

  // The key goes to encrypted platform storage, so it is committed once when
  // the field is done rather than on every keystroke. On Linux a per-keystroke
  // write can prompt for a keyring unlock each time.
  final _apiKeyFocus = FocusNode();

  List<String> _systemFolders = [];
  Map<String, int?> _consoleSelections = {};
  String _version = '';

  @override
  void initState() {
    super.initState();
    libraryFolderListenable.addListener(_load);
    _apiKeyFocus.addListener(_commitApiKeyOnBlur);
    _load();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // No platform plugin under tests, leave the label blank.
    }
  }

  @override
  void dispose() {
    libraryFolderListenable.removeListener(_load);
    _apiKeyFocus.removeListener(_commitApiKeyOnBlur);
    _apiKeyFocus.dispose();
    _usernameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _extensionsCtrl.dispose();
    _ignoredCtrl.dispose();
    _excludedCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final extensions = await ScanSettings.enabledExtensionsText();
    final ignored = await ScanSettings.ignoredFoldersText();
    final excluded = await ScanSettings.excludedFilesText();
    final apiKey = await readApiKey();

    final overrides = await ScanSettings.folderConsoleOverrides();
    final ignoredLower = (await ScanSettings.ignoredFolders())
        .map((e) => e.toLowerCase())
        .toSet();
    final root = prefs.getString(PrefKeys.lastFolder);
    final folders = <String>[];
    final selections = <String, int?>{};
    final rootDir = root == null ? null : Directory(root);
    if (rootDir != null && await rootDir.exists()) {
      await for (final d in rootDir.list()) {
        if (d is! Directory) continue;
        final name = p.basename(d.path);
        if (ignoredLower.contains(name.toLowerCase())) continue;
        folders.add(name);
        selections[name] = overrides[name];
      }
      folders.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    setState(() {
      _usernameCtrl.text = prefs.getString(PrefKeys.raUsername) ?? '';
      _apiKeyCtrl.text = apiKey;
      _extensionsCtrl.text = extensions;
      _ignoredCtrl.text = ignored;
      _excludedCtrl.text = excluded;
      _systemFolders = folders;
      _consoleSelections = selections;
    });
  }

  // Sections persist immediately; there is no batched Save step.
  Future<void> _setStringPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _commitApiKeyOnBlur() {
    if (!_apiKeyFocus.hasFocus) saveApiKey(_apiKeyCtrl.text.trim());
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all scanned data?'),
        content: const Text(
            'This deletes every scan result. Your ROM files are untouched, '
            'but everything must be re-scanned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirm != true) return;
    await (widget.library ?? Library.instance).clear();
    _toast('All scanned data cleared.');
  }

  Future<void> _backup() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Back up library',
        fileName:
            'rarm-backup-${DateTime.now().toIso8601String().split('T').first}.zip',
      );
      if (path == null) return; // cancelled
      await const BackupService().create(path);
      _toast('Backup saved to $path');
    } catch (e) {
      _toast('Backup failed');
    }
  }

  Future<void> _restore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            'This overwrites your current scan results, playlists, '
            'and settings. Restart the app afterwards.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await FilePicker.platform.pickFiles(
        dialogTitle: 'Choose a backup zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      final path = res?.files.single.path;
      if (path == null) return; // cancelled
      await const BackupService().restore(path);
      _toast('Restored. Restart the app to load the backup.');
    } catch (e) {
      _toast('Restore failed');
    }
  }

  // Imports Skraper / gamelist.xml data from a chosen folder, matched to
  // already-scanned ROMs. Fills RA metadata gaps and adds local images.
  Future<void> _importScrapedData() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) return;

    // Scanned ROM absolute paths from the library, to match gamelist entries.
    final scanned = await (widget.library ?? Library.instance).allRomPaths();
    if (!mounted) return;
    ImportResult result;
    try {
      // Detection + parse run off the UI isolate.
      result = await importFromDirectory(path, scanned);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't import scraped data")));
      return;
    }
    if (result.matched.isEmpty && result.unmatched == 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No gamelist.xml found in that folder')));
      return;
    }
    await ScrapedStore.instance.putAll(result.matched);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
        content: Text('Imported ${result.matched.length} games across '
            '${result.systemCount} systems, ${result.unmatched} unmatched')));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetExtensions() {
    final defaults = kDefaultRomExtensions.join(', ');
    _extensionsCtrl.text = defaults;
    ScanSettings.setEnabledExtensions(defaults);
  }

  // Section heading with an optional one-line description.
  Widget _heading(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Account',
            'Web API key from retroachievements.org → Settings → Keys.'),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _setStringPref(PrefKeys.raUsername, v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('settings-apikey'),
          controller: _apiKeyCtrl,
          focusNode: _apiKeyFocus,
          decoration: const InputDecoration(
            labelText: 'Web API key',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          obscureText: true,
          onEditingComplete: () => saveApiKey(_apiKeyCtrl.text.trim()),
        ),
      ],
    );
  }

  Widget _scanFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Scan filters',
            'Comma-separated. Unlisted extensions are skipped; ignored folders '
            'are hidden and never scanned.'),
        TextField(
          controller: _extensionsCtrl,
          decoration: const InputDecoration(
            labelText: 'Extensions',
            hintText: 'chd, nds, gb, gba, ...',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 1,
          maxLines: 3,
          onChanged: (v) => ScanSettings.setEnabledExtensions(v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: 'Replaces the list above with the extensions the app '
                'ships with, discarding your edits.',
            child: TextButton(
              onPressed: _resetExtensions,
              child: const Text('Reset to defaults'),
            ),
          ),
        ),
        TextField(
          controller: _ignoredCtrl,
          decoration: const InputDecoration(
            labelText: 'Ignored folders',
            hintText: 'BIOS, Saves, Cheats',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 1,
          maxLines: 2,
          onChanged: (v) => ScanSettings.setIgnoredFolders(v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _excludedCtrl,
          decoration: const InputDecoration(
            labelText: 'Excluded files',
            hintText: r'C:\roms\snes\bad-dump.sfc',
            helperText: 'Full paths, one per line. Excluded files are hidden and '
                'skipped, but not deleted.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
            isDense: true,
          ),
          minLines: 2,
          maxLines: 6,
          onChanged: (v) => ScanSettings.setExcludedFilesFromText(v),
        ),
      ],
    );
  }

  Widget _displaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Display',
            'Show the full system name ("Super Nintendo") or the original '
            'folder name ("SNES") on cards and titles.'),
        ValueListenableBuilder<NameMode>(
          valueListenable: nameModeListenable,
          builder: (context, mode, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Show full system names'),
            value: mode == NameMode.systemName,
            onChanged: (on) => saveNameMode(
                on ? NameMode.systemName : NameMode.folderName),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: combineSystemsListenable,
          builder: (context, on, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Combine systems'),
            subtitle: const Text(
                'Merge folders that map to the same console into one card '
                'on Home.'),
            value: on,
            onChanged: saveCombineSystems,
          ),
        ),
      ],
    );
  }

  Widget _themeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Theme',
            'Light or RetroAchievements (dark). Applies immediately.'),
        ValueListenableBuilder<AppTheme>(
          valueListenable: appThemeListenable,
          builder: (context, theme, _) => SegmentedButton<AppTheme>(
            segments: const [
              ButtonSegment(value: AppTheme.light, label: Text('Light')),
              ButtonSegment(
                  value: AppTheme.dark, label: Text('RetroAchievements')),
            ],
            selected: {theme},
            showSelectedIcon: false,
            onSelectionChanged: (s) => saveAppTheme(s.first),
          ),
        ),
      ],
    );
  }

  Widget _systemMappingSection() {
    final consoleItems = ConsoleMap.consoleNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('System mapping',
            'Each subfolder is hashed as a specific console. Override a wrong '
            'guess here; disc systems (PS1, PSP, Saturn, …) must be set.'),
        if (_systemFolders.isEmpty)
          Text(
            'No library folder selected yet. Pick one on the Home screen, then '
            'reopen Settings to map its subfolders.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          ..._systemFolders.map((folder) {
            final detected = ConsoleMap.idForFolder(folder);
            final detectedName = detected == null
                ? 'none'
                : ConsoleMap.nameFor(detected) ?? 'id $detected';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(folder, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 12),
                  // isExpanded: otherwise the dropdown sizes to its widest
                  // item and overflows on phones.
                  Expanded(
                    child: DropdownButton<int?>(
                    isExpanded: true,
                    value: _consoleSelections[folder],
                    isDense: true,
                    hint: Text('Auto ($detectedName)'),
                    onChanged: (v) {
                      setState(() => _consoleSelections[folder] = v);
                      ScanSettings.setFolderConsoleOverride(folder, v);
                    },
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Auto-detect ($detectedName)'),
                      ),
                      ...consoleItems.map((e) => DropdownMenuItem<int?>(
                            value: e.key,
                            child: Text(e.value),
                          )),
                    ],
                  ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _libraryFolderSection() {
    return ValueListenableBuilder<String?>(
      valueListenable: libraryFolderListenable,
      builder: (context, folder, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Library folder',
              'The root folder holding your per-system ROM subfolders.'),
          if (folder != null)
            Text(folder, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: Text(folder == null ? 'Pick folder' : 'Change folder'),
            onPressed: () => pickLibraryFolder(context),
          ),
        ],
      ),
    );
  }

  Widget _dataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Data',
            'Back up or restore your library (scans, playlists, '
            'settings). Clear scanned results to force a re-scan.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tooltip(
              message: 'Writes a zip holding your scan results, playlists and '
                  'settings. ROM files are not included.',
              child: OutlinedButton.icon(
                onPressed: _backup,
                icon: const Icon(Icons.save_alt),
                label: const Text('Back up'),
              ),
            ),
            Tooltip(
              message: 'Loads a backup zip, replacing everything you have now. '
                  'Needs an app restart afterwards.',
              child: OutlinedButton.icon(
                onPressed: _restore,
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
              ),
            ),
            Tooltip(
              message: 'Reads gamelist.xml files from a Skraper or '
                  'EmulationStation folder and attaches their box art and '
                  'descriptions to ROMs you already scanned.',
              child: OutlinedButton.icon(
                onPressed: _importScrapedData,
                icon: const Icon(Icons.image_search),
                label: const Text('Import scraped data…'),
              ),
            ),
            Tooltip(
              message: 'Opens the first-run wizard again (library folder, '
                  'RetroAchievements account, emulators).',
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupWizard()),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Re-run setup'),
              ),
            ),
            Tooltip(
              message: 'Deletes every scan result, hash and match from the app. '
                  'Your ROM files stay on disk, but you have to re-scan.',
              child: OutlinedButton(
                onPressed: _clearAll,
                child: const Text('Clear all scanned data'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Version + author. Shown only on mobile; the desktop sidebar already
  // carries the same label in its bottom-left corner.
  Widget _aboutSection() {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('About', 'Retroachievements Rom Manager by George Englezos.'),
        if (_version.isNotEmpty) Text(_version, style: style),
      ],
    );
  }

  Widget _column(List<Widget> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const Divider(height: 40),
          sections[i],
        ],
      ],
    );
  }

  // One tab's body; two columns when there's room, else stacked.
  Widget _tabBody(List<Widget> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760 && sections.length > 1;
        final split = (sections.length + 1) ~/ 2;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: twoColumns ? 1400 : 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: twoColumns
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _column(sections.sublist(0, split))),
                        const SizedBox(width: 40),
                        Expanded(child: _column(sections.sublist(split))),
                      ],
                    )
                  : _column(sections),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shell already shows the title on mobile; AppBar keeps only the tabs.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final general = [
      _accountSection(),
      _libraryFolderSection(),
      _scanFiltersSection(),
      _displaySection(),
      _themeSection(),
      _dataSection(),
      // Mobile has no sidebar, so surface the version here.
      if (!wide) _aboutSection(),
    ];
    final systems = [_systemMappingSection()];
    final emulation = [
      EmulatorSettingsSection(library: widget.library),
    ];
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: wide ? const Text('Settings') : null,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'General'),
              Tab(text: 'Systems'),
              Tab(text: 'Emulation (beta)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _tabBody(general),
            _tabBody(systems),
            _tabBody(emulation),
          ],
        ),
      ),
    );
  }
}

/// Emulators + per-system connections (settings-first, Playnite-style).
class EmulatorSettingsSection extends StatefulWidget {
  final Library? library; // injectable for tests

  const EmulatorSettingsSection({super.key, this.library});

  @override
  State<EmulatorSettingsSection> createState() =>
      _EmulatorSettingsSectionState();
}

class _EmulatorSettingsSectionState extends State<EmulatorSettingsSection> {
  _EmulatorData? _data;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // State field, not FutureBuilder: repaints reliably after a native picker.
  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _data = data);
  }

  Future<_EmulatorData> _load() async {
    final emulators = await EmulatorStore.emulators();
    final connections = await EmulatorStore.connections();
    final fullscreen = await EmulatorStore.launchFullscreen();
    final summaries =
        await (widget.library ?? Library.instance).summaries();
    // Scanned consoles + folder-mapped consoles, so an emulator can be set
    // before any scan.
    final consoleIds = <int>{
      for (final s in summaries)
        if (s.consoleId != null && ConsoleMap.consoleNames[s.consoleId!] != null)
          s.consoleId!,
      ...await _mappedConsoleIds(),
    }.toList()
      ..sort((a, b) => ConsoleMap.consoleNames[a]!
          .compareTo(ConsoleMap.consoleNames[b]!));
    return _EmulatorData(emulators, connections, consoleIds, fullscreen);
  }

  // Console ids for the root subfolders: overrides first, then name detection.
  Future<Set<int>> _mappedConsoleIds() async {
    final prefs = await SharedPreferences.getInstance();
    final root = prefs.getString(PrefKeys.lastFolder);
    if (root == null || !Directory(root).existsSync()) return {};
    final overrides = await ScanSettings.folderConsoleOverrides();
    final ignored = (await ScanSettings.ignoredFolders())
        .map((e) => e.toLowerCase())
        .toSet();
    final ids = <int>{};
    for (final d in Directory(root).listSync().whereType<Directory>()) {
      final name = p.basename(d.path);
      if (ignored.contains(name.toLowerCase())) continue;
      final id = overrides[name] ?? ConsoleMap.idForFolder(name);
      if (id != null && ConsoleMap.consoleNames[id] != null) ids.add(id);
    }
    return ids;
  }

  Future<void> _addEmulator() async {
    final emu = await pickNewEmulator(context);
    if (emu == null) return;
    await EmulatorStore.addEmulator(emu);
    await _refresh();
    _toast('Added ${emu.name}. Connected its default systems below.');
  }

  Future<void> _editEmulatorExe(Emulator emu) async {
    final picked = await pickNewEmulator(context,
        dialogTitle: 'Choose the emulator executable for ${emu.name}');
    if (picked == null) return;
    await EmulatorStore.updateEmulatorExe(emu.id, picked.exePath);
    await _refresh();
    _toast('Updated ${emu.name}.');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final subhead = Theme.of(context).textTheme.titleSmall;
    final data = _data;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emulators', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Platform.isAndroid
                  ? 'Add your emulator apps, then connect each system to one. '
                      'Tapping Play sends the ROM straight to that app.'
                  : 'Add your emulators, then connect each system to one. Adding '
                      'RetroArch auto-fills the right core for most systems; '
                      'standalone emulators (Dolphin, PCSX2, DuckStation, PPSSPP) '
                      'connect their own.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text('Your emulators', style: subhead),
            const SizedBox(height: 4),
            if (data == null)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              // Fullscreen is a desktop CLI flag; hidden on Android.
              if (!Platform.isAndroid)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Launch games in fullscreen'),
                  value: data.launchFullscreen,
                  onChanged: (v) async {
                    await EmulatorStore.setLaunchFullscreen(v ?? false);
                    await _refresh();
                  },
                ),
              if (data.emulators.isEmpty)
                const Text('None yet, add one below.',
                    style: TextStyle(fontStyle: FontStyle.italic))
              else
                for (final emu in data.emulators)
                  Column(
                    key: ValueKey(emu.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(emu.name),
                        subtitle: Text(emu.exePath,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip:
                                  Platform.isAndroid ? 'Change app' : 'Change exe',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editEmulatorExe(emu),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await EmulatorStore.removeEmulator(emu.id);
                                await _refresh();
                              },
                            ),
                          ],
                        ),
                      ),
                      // Args are desktop-only; Android launches via intent.
                      if (!Platform.isAndroid)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AutoSaveTextField(
                            key: ValueKey('args-${emu.id}'),
                            value: emu.extraArgs,
                            label: 'Extra arguments (applied to all this '
                                "emulator's systems)",
                            onSave: (v) =>
                                EmulatorStore.setExtraArgs(emu.id, v),
                          ),
                        ),
                    ],
                  ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addEmulator,
                icon: const Icon(Icons.add),
                label: Text(Platform.isAndroid
                    ? 'Add emulator (pick app)'
                    : 'Add emulator (browse exe)'),
              ),
              const SizedBox(height: 16),
              Text('Systems', style: subhead),
              const SizedBox(height: 4),
              if (data.consoleIds.isEmpty)
                const Text('No scanned systems yet.',
                    style: TextStyle(fontStyle: FontStyle.italic))
              else
                for (final consoleId in data.consoleIds)
                  _SystemRow(
                    key: ValueKey(consoleId),
                    consoleId: consoleId,
                    name: ConsoleMap.consoleNames[consoleId]!,
                    emulators: data.emulators,
                    connection: data.connections[consoleId],
                    onChanged: _refresh,
                  ),
            ],
          ],
        );
  }
}

class _EmulatorData {
  final List<Emulator> emulators;
  final Map<int, EmulatorConnection> connections;
  final List<int> consoleIds;
  final bool launchFullscreen;
  _EmulatorData(
      this.emulators, this.connections, this.consoleIds, this.launchFullscreen);
}

/// Text field that saves on blur/enter and reseeds when [value] changes
/// (state is reused across reloads when the parent keys it).
class _AutoSaveTextField extends StatefulWidget {
  final String value;
  final String label;
  final ValueChanged<String> onSave;

  const _AutoSaveTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onSave,
  });

  @override
  State<_AutoSaveTextField> createState() => _AutoSaveTextFieldState();
}

class _AutoSaveTextFieldState extends State<_AutoSaveTextField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode()..addListener(_onBlur);

  void _onBlur() {
    if (!_focus.hasFocus) widget.onSave(_ctrl.text);
  }

  @override
  void didUpdateWidget(_AutoSaveTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Never clobber in-progress typing; reseed only while unfocused.
    if (widget.value != oldWidget.value && !_focus.hasFocus) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onBlur);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onEditingComplete: () => widget.onSave(_ctrl.text),
    );
  }
}

/// One library console: pick its emulator + edit the launch args.
class _SystemRow extends StatelessWidget {
  final int consoleId;
  final String name;
  final List<Emulator> emulators;
  final EmulatorConnection? connection;
  final VoidCallback onChanged;

  const _SystemRow({
    super.key,
    required this.consoleId,
    required this.name,
    required this.emulators,
    required this.connection,
    required this.onChanged,
  });

  Future<void> _saveArgs(String text) async {
    final emulatorId = connection?.emulatorId;
    if (emulatorId == null) return;
    await EmulatorStore.setConnection(consoleId, emulatorId, text);
  }

  Future<void> _selectEmulator(String? emulatorId) async {
    if (emulatorId == null) {
      await EmulatorStore.clearConnection(consoleId);
      onChanged();
      return;
    }
    final emu = emulators.where((e) => e.id == emulatorId).firstOrNull;
    if (emu == null) return;
    final args =
        EmulatorCatalog.defaultArgsFor(consoleId, emu.kindId, emu.exePath) ??
            '"{file.path}"';
    await EmulatorStore.setConnection(consoleId, emulatorId, args);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = connection?.emulatorId;
    final valid = emulators.any((e) => e.id == selectedId) ? selectedId : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 160, child: Text(name)),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: valid,
                  hint: const Text('Not set'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Not set')),
                    for (final e in emulators)
                      DropdownMenuItem<String?>(
                          value: e.id, child: Text(e.name)),
                  ],
                  onChanged: _selectEmulator,
                ),
              ),
            ],
          ),
          // Args are desktop-only; Android launches via intent.
          if (valid != null && !Platform.isAndroid)
            Padding(
              padding: const EdgeInsets.only(left: 160, top: 4),
              child: _AutoSaveTextField(
                key: ValueKey('sysargs-$consoleId'),
                value: connection?.args ?? '',
                label: 'Arguments ({file.path} is the ROM)',
                onSave: _saveArgs,
              ),
            ),
        ],
      ),
    );
  }
}
