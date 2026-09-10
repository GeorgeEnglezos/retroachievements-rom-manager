import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_tokens.dart';
import '../services/android_emulators.dart';
import '../services/app_mode.dart';
import '../services/play_view.dart';
import '../services/app_theme.dart';
import '../services/backup_service.dart';
import '../services/console_map.dart';
import '../services/credentials.dart';
import '../services/display_name.dart';
import '../services/emulator_catalog.dart';
import '../services/emulator_finder.dart';
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

  Future<void> _pruneMissing() async {
    final removed =
        await (widget.library ?? Library.instance).pruneMissingSystems();
    _toast(removed == 0
        ? 'No missing systems to remove.'
        : 'Removed $removed missing system${removed == 1 ? '' : 's'}.');
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

  // Section heading with an optional one-line description. The description is
  // held to a readable measure so a wide window does not stretch it into one
  // long line.
  Widget _heading(String title, String description) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ui.display.copyWith(fontSize: 17)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(description,
              style: TextStyle(fontSize: 13, height: 1.45, color: ui.muted)),
        ),
        const SizedBox(height: 16),
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

  Widget _modeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Mode',
            'Play hides the maintenance tabs, scans, multi-select and every '
            'delete button, so the app is safe to hand over. A controller '
            'drives either mode.'),
        ValueListenableBuilder<AppMode>(
          valueListenable: appModeListenable,
          builder: (context, mode, _) => SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(value: AppMode.cleaning, label: Text('Cleaning')),
              ButtonSegment(value: AppMode.gaming, label: Text('Play')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => saveAppMode(s.first),
          ),
        ),
      ],
    );
  }

  // One switch bound to a single PlayView flag.
  Widget _playSwitch(
    String title,
    bool value,
    PlayView Function(bool) update, {
    String? subtitle,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (on) => savePlayView(update(on)),
    );
  }

  Widget _playViewSection() {
    return ValueListenableBuilder<PlayView>(
      valueListenable: playViewListenable,
      builder: (context, v, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Play listings',
              'What ROM lists show while Play is on. Cleaning always shows '
              'everything.'),
          _playSwitch('RetroAchievements names', v.raTitle,
              (on) => v.copyWith(raTitle: on),
              subtitle: 'Off names games by their file name instead.'),
          _playSwitch(
              'File name line', v.fileName, (on) => v.copyWith(fileName: on)),
          _playSwitch(
              'File size', v.fileSize, (on) => v.copyWith(fileSize: on)),
          _playSwitch('Achievement count badge', v.achievementCount,
              (on) => v.copyWith(achievementCount: on)),
          _playSwitch('Hot badge', v.hot, (on) => v.copyWith(hot: on)),
          _playSwitch('No-achievements badge', v.noAchievements,
              (on) => v.copyWith(noAchievements: on)),
          _playSwitch(
              'File name tags', v.fileTags, (on) => v.copyWith(fileTags: on),
              subtitle: 'Region, HACK, ENG and friends, read off the file name.'),
          const SizedBox(height: 8),
          Text('Layout', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SegmentedButton<PlayLayout>(
            segments: const [
              ButtonSegment(value: PlayLayout.follow, label: Text('My choice')),
              ButtonSegment(value: PlayLayout.list, label: Text('List')),
              ButtonSegment(value: PlayLayout.grid, label: Text('Grid')),
            ],
            selected: {v.layout},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                savePlayView(v.copyWith(layout: s.first)),
          ),
        ],
      ),
    );
  }

  Widget _themeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Theme', 'Pick a colour palette. Applies immediately.'),
        ValueListenableBuilder<AppTheme>(
          valueListenable: appThemeListenable,
          builder: (context, current, _) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final theme in AppTheme.values)
                _ThemeSwatch(
                  theme: theme,
                  selected: theme == current,
                  onTap: () => saveAppTheme(theme),
                ),
            ],
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
              message: 'Deletes scan results for library folders that no longer '
                  'exist (e.g. after moving or renaming your ROMs). Folders '
                  'still on disk are untouched.',
              child: OutlinedButton.icon(
                onPressed: _pruneMissing,
                icon: const Icon(Icons.folder_off_outlined),
                label: const Text('Remove missing systems'),
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
    final ui = context.ui;
    return Column(
      // Stretch, so a section's closing hairline runs the width of the column
      // rather than stopping at whatever its widest control happens to be.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++)
          Container(
            padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 28),
            margin: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 28),
            decoration: i == sections.length - 1
                ? null
                : BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: ui.border, width: ui.borderWidth))),
            child: sections[i],
          ),
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
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
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
      _modeSection(),
      _playViewSection(),
      _themeSection(),
      _dataSection(),
      // Mobile has no sidebar, so surface the version here.
      if (!wide) _aboutSection(),
    ];
    final systems = [_systemMappingSection()];
    final emulation = [
      EmulatorSettingsSection(library: widget.library),
    ];
    final ui = context.ui;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ui.background,
        // No AppBar: the tabs sit on the page under the title, on a hairline
        // that runs the full width, the way the rest of the app separates
        // sections. The shell already shows the title on mobile.
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, wide ? 24 : 10, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) ...[
                    Text('Settings', style: ui.display.copyWith(fontSize: 26)),
                    const SizedBox(height: 16),
                  ],
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: 'General'),
                        Tab(text: 'Systems'),
                        Tab(text: 'Emulation (beta)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: ui.borderWidth, color: ui.border),
            Expanded(
              child: TabBarView(
                children: [
                  _tabBody(general),
                  _tabBody(systems),
                  _tabBody(emulation),
                ],
              ),
            ),
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
  bool _scanning = false;

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
    // Android emulators are installed apps, so the first time this tab opens we
    // sweep them in without asking. After that it's the Detect button, so a
    // removed emulator stays removed.
    if (Platform.isAndroid && await EmulatorStore.takeAndroidSweep()) {
      await _addDetectedApps();
    }
    final emulators = await EmulatorStore.emulators();
    final connections = await EmulatorStore.connections();
    final fullscreen = await EmulatorStore.launchFullscreen();
    // The library's filtered systems are the single source, so this list
    // matches the home grid / badge: ignored, missing, out-of-root, and
    // never-scanned folders never leak in here.
    final summaries =
        await (widget.library ?? Library.instance).summaries();
    final consoleIds = <int>{
      for (final s in summaries)
        if (s.consoleId != null && ConsoleMap.consoleNames[s.consoleId!] != null)
          s.consoleId!,
    }.toList()
      ..sort((a, b) => ConsoleMap.consoleNames[a]!
          .compareTo(ConsoleMap.consoleNames[b]!));
    return _EmulatorData(emulators, connections, consoleIds, fullscreen);
  }

  Future<void> _addEmulator() async {
    final emu = await pickNewEmulator(context);
    if (emu == null) return;
    await EmulatorStore.addEmulator(emu);
    await _refresh();
    _toast('Added ${emu.name}. Connected its default systems below.');
  }

  // Adds every installed app we recognise as an emulator, skipping kinds the
  // user already has. Returns what it added.
  Future<List<Emulator>> _addDetectedApps() async {
    final found = emulatorsFromApps(await AndroidEmulators.installedApps(),
        existing: await EmulatorStore.emulators());
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
      _toast(found.isEmpty
          ? 'No new emulator apps found.'
          : 'Added ${found.map((e) => e.name).join(', ')}. '
              'Connected their default systems below.');
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
      final found = await findEmulators(Directory(folder),
          existing: _data?.emulators ?? const []);
      for (final emu in found) {
        await EmulatorStore.addEmulator(emu);
      }
      await _refresh();
      _toast(found.isEmpty
          ? 'No new emulators found in that folder.'
          : 'Added ${found.map((e) => e.name).join(', ')}. '
              'Connected their default systems below.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
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
              style: TextStyle(fontSize: 12, color: context.ui.muted),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _scanning ? null : _addEmulator,
                    icon: const Icon(Icons.add),
                    label: Text(Platform.isAndroid
                        ? 'Add emulator (pick app)'
                        : 'Add emulator (browse exe)'),
                  ),
                  // Desktop searches a folder of exes; Android sweeps the
                  // installed apps, so there's nothing to browse for.
                  OutlinedButton.icon(
                    onPressed: _scanning
                        ? null
                        : Platform.isAndroid
                            ? _detectEmulatorApps
                            : _scanForEmulators,
                    icon: _scanning
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.travel_explore),
                    label: Text(_scanning
                        ? 'Scanning…'
                        : Platform.isAndroid
                            ? 'Detect installed emulators'
                            : 'Scan a folder for emulators'),
                  ),
                ],
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

/// One tappable palette card in the theme picker. Painted in the palette's own
/// colours so it previews the theme; the selection ring uses the *current*
/// theme's accent so it reads against the live UI.
class _ThemeSwatch extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui; // live theme, for the selection ring
    final t = theme.tokens; // this card's palette, for the preview
    final dots = [t.accent, t.supported, t.accentAlt, t.accentGames];
    return InkWell(
      onTap: onTap,
      borderRadius: ui.roundMd,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          borderRadius: ui.roundMd,
          border: Border.all(
            color: selected ? ui.accent : t.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: ui.roundMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: double.infinity,
                color: t.background,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    for (final c in dots)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: t.surface,
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.label,
                        style: t.body.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 16, color: ui.accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
