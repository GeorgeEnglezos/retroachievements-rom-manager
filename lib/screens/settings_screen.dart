import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/ui_tokens.dart';
import '../services/app_mode.dart';
import '../services/play_view.dart';
import '../services/backup_service.dart';
import '../services/credentials.dart';
import '../services/data_wipe.dart';
import '../services/display_name.dart';
import '../services/library.dart';
import '../services/log_service.dart';
import '../services/pref_keys.dart';
import '../services/library_folder.dart';
import '../widgets/clear_data_dialog.dart';
import '../widgets/app_mode_toggle.dart';
import '../widgets/pick_library_folder.dart';
import '../widgets/restore_backup.dart';
import '../widgets/theme_picker.dart';
import '../services/scan_settings.dart';
import '../services/settings_bus.dart';
import '../services/rom_tap.dart';
import '../widgets/system_settings_section.dart';
import '../widgets/ui/ui_card.dart';
import '../widgets/ui_scale_control.dart';
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

    setState(() {
      _usernameCtrl.text = prefs.getString(PrefKeys.raUsername) ?? '';
      _apiKeyCtrl.text = apiKey;
      _extensionsCtrl.text = extensions;
      _ignoredCtrl.text = ignored;
      _excludedCtrl.text = excluded;
    });
  }

  // Sections persist immediately; there is no batched Save step.
  Future<void> _setStringPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    publishSettingsChange();
  }

  void _commitApiKeyOnBlur() {
    if (!_apiKeyFocus.hasFocus) {
      saveApiKey(_apiKeyCtrl.text.trim()).then((_) => publishSettingsChange());
    }
  }

  Future<void> _clearData() async {
    final targets = await showClearDataDialog(context);
    if (targets == null || targets.isEmpty || !mounted) return;
    try {
      await DataWipe(library: widget.library).clear(targets);
      _toast(
        'Deleted ${targets.length} of '
        '${ClearTarget.values.length} kinds of data.',
      );
    } catch (e) {
      LogService.error('Settings/clearData', 'wipe failed', err: e);
      _toast('Could not delete everything, see the log for details.');
    }
  }

  Future<void> _backup() async {
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Back up library',
        fileName:
            'rarm-backup-${DateTime.now().toIso8601String().split('T').first}.zip',
      );
      if (path == null) return; // cancelled
      _toast('Backing up, this can take a while on a large library.');
      await const BackupService().create(path);
      _toast('Backup saved to $path');
    } catch (e) {
      LogService.error('Settings/backup', 'backup failed', err: e);
      _toast('Backup failed, see the log for details.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          child: Text(
            description,
            style: TextStyle(fontSize: 13, height: 1.45, color: ui.muted),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Account',
          'Web API key from retroachievements.org → Settings → Keys.',
        ),
        UiFocusZoom(
          child: TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              isDense: true,
            ),
            onChanged: (v) => _setStringPref(PrefKeys.raUsername, v.trim()),
          ),
        ),
        const SizedBox(height: 12),
        UiFocusZoom(
          child: TextField(
            key: const Key('settings-apikey'),
            controller: _apiKeyCtrl,
            focusNode: _apiKeyFocus,
            decoration: const InputDecoration(
              labelText: 'Web API key',
              isDense: true,
            ),
            obscureText: true,
            onEditingComplete: () => saveApiKey(
              _apiKeyCtrl.text.trim(),
            ).then((_) => publishSettingsChange()),
          ),
        ),
      ],
    );
  }

  Widget _scanFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Scan filters',
          'Comma-separated. Unlisted extensions are skipped; ignored folders '
              'are hidden and never scanned.',
        ),
        UiFocusZoom(
          child: TextField(
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
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message:
                'Replaces the list above with the extensions the app '
                'ships with, discarding your edits.',
            child: UiFocusZoom(
              child: TextButton(
                onPressed: _resetExtensions,
                child: const Text('Reset to defaults'),
              ),
            ),
          ),
        ),
        UiFocusZoom(
          child: TextField(
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
        ),
        const SizedBox(height: 12),
        UiFocusZoom(
          child: TextField(
            controller: _excludedCtrl,
            decoration: const InputDecoration(
              labelText: 'Excluded files',
              hintText: r'C:\roms\snes\bad-dump.sfc',
              helperText:
                  'Full paths, one per line. Excluded files are hidden and '
                  'skipped, but not deleted.',
              helperMaxLines: 2,
              isDense: true,
            ),
            minLines: 2,
            maxLines: 6,
            onChanged: (v) => ScanSettings.setExcludedFilesFromText(v),
          ),
        ),
      ],
    );
  }

  Widget _displaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Display',
          'Show the full system name ("Super Nintendo") or the original '
              'folder name ("SNES") on cards and titles.',
        ),
        ValueListenableBuilder<NameMode>(
          valueListenable: nameModeListenable,
          builder: (context, mode, _) => UiFocusZoom(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Show full system names'),
              value: mode == NameMode.systemName,
              onChanged: (on) => nameModeListenable.save(
                on ? NameMode.systemName : NameMode.folderName,
              ),
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: combineSystemsListenable,
          builder: (context, on, _) => UiFocusZoom(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Combine systems'),
              subtitle: const Text(
                'Merge folders that map to the same console into one card '
                'on Home.',
              ),
              value: on,
              onChanged: saveCombineSystems,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('UI scale', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 2),
        Text(
          'Zoom the whole app in or out. Applies immediately.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        const UiScaleControl(),
      ],
    );
  }

  Widget _modeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Mode', kAppModeHelp),
        ValueListenableBuilder<AppMode>(
          valueListenable: appModeListenable,
          builder: (context, mode, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppModeToggle(),
              if (mode == AppMode.gaming) ...[
                const SizedBox(height: 24),
                _kioskListings(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _romTapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Clicking a game',
          'What a plain click on a game does. Ctrl/shift-click still '
              'multi-selects, and Play stays on the right-click menu either way.',
        ),
        ValueListenableBuilder<RomTapAction>(
          valueListenable: romTapListenable,
          builder: (context, action, _) => UiFocusZoom(
            child: SegmentedButton<RomTapAction>(
              segments: const [
                ButtonSegment(
                  value: RomTapAction.detail,
                  label: Text('Open details'),
                ),
                ButtonSegment(value: RomTapAction.play, label: Text('Play')),
              ],
              selected: {action},
              showSelectedIcon: false,
              onSelectionChanged: (s) => romTapListenable.save(s.first),
            ),
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
    return UiFocusZoom(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: (on) => savePlayView(update(on)),
      ),
    );
  }

  Widget _kioskListings() {
    return ValueListenableBuilder<PlayView>(
      valueListenable: playViewListenable,
      builder: (context, v, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Kiosk listings',
            'What ROM lists show in Kiosk mode. Cleaning always shows '
                'everything.',
          ),
          _playSwitch(
            'Achievement count',
            v.achievementCount,
            (on) => v.copyWith(achievementCount: on),
            subtitle: 'The ACH badge, earned/total and the progress bar.',
          ),
          _playSwitch('Hot badge', v.hot, (on) => v.copyWith(hot: on)),
          _playSwitch(
            'No-achievements badge',
            v.noAchievements,
            (on) => v.copyWith(noAchievements: on),
          ),
          _playSwitch(
            'File name tags',
            v.fileTags,
            (on) => v.copyWith(fileTags: on),
            subtitle: 'Region, HACK, ENG and friends, read off the file name.',
          ),
          const SizedBox(height: 8),
          Text('Layout', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          UiFocusZoom(
            child: SegmentedButton<PlayLayout>(
              segments: const [
                ButtonSegment(
                  value: PlayLayout.follow,
                  label: Text('My choice'),
                ),
                ButtonSegment(value: PlayLayout.list, label: Text('List')),
                ButtonSegment(value: PlayLayout.grid, label: Text('Grid')),
              ],
              selected: {v.layout},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  savePlayView(v.copyWith(layout: s.first)),
            ),
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
        const ThemePicker(),
      ],
    );
  }

  Widget _libraryFolderSection() {
    return ValueListenableBuilder<String?>(
      valueListenable: libraryFolderListenable,
      builder: (context, folder, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Library folder',
            'The root folder holding your per-system ROM subfolders.',
          ),
          if (folder != null)
            Text(folder, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          UiFocusZoom(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(folder == null ? 'Pick folder' : 'Change folder'),
              onPressed: () => pickLibraryFolder(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Data',
          'Back up or restore everything the app has saved. Delete it to '
              'start over from a fresh scan.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tooltip(
              message:
                  'Writes a zip holding your scan results, imported '
                  'metadata, cached artwork, playlists and settings. ROM '
                  'files and your API key are not included.',
              child: UiFocusZoom(
                child: OutlinedButton.icon(
                  onPressed: _backup,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Create Data Backup'),
                ),
              ),
            ),
            Tooltip(
              message:
                  'Loads a backup zip, replacing everything you have '
                  'now except your API key. Needs an app restart afterwards.',
              child: UiFocusZoom(
                child: OutlinedButton.icon(
                  onPressed: () => restoreBackup(context),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore Data Backup'),
                ),
              ),
            ),
            Tooltip(
              message:
                  'Choose what to delete: scan results, playlists, '
                  'imported metadata, cached artwork. Your ROM files, '
                  'settings and login are never touched.',
              child: UiFocusZoom(
                child: OutlinedButton.icon(
                  onPressed: _clearData,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Data'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _heading(
          'Setup',
          'Opens the first-run wizard again (RetroAchievements account, '
              'library folder, mode, theme).',
        ),
        UiFocusZoom(
          child: OutlinedButton.icon(
            onPressed: () => showSetupWizard(context),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Setup Wizard'),
          ),
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

  // Each section is its own card, so a long tab reads as a stack of panels
  // instead of one ruled column.
  Widget _column(List<Widget> sections) {
    return Column(
      // Stretch, so every card in the column is the same width whatever its
      // widest control happens to be.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == sections.length - 1 ? 0 : 16),
            child: UiCard(
              padding: const EdgeInsets.all(20),
              child: sections[i],
            ),
          ),
      ],
    );
  }

  // Centred, width-capped scroll body shared by every tab.
  Widget _scroll(double maxWidth, Widget child) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: child,
      ),
    ),
  );

  // One tab's body; two columns of section cards when there's room.
  Widget _tabBody(List<Widget> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760 && sections.length > 1;
        final split = (sections.length + 1) ~/ 2;
        return _scroll(
          twoColumns ? 1400 : 720,
          twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _column(sections.sublist(0, split))),
                    const SizedBox(width: 32),
                    Expanded(child: _column(sections.sublist(split))),
                  ],
                )
              : _column(sections),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shell already shows the title on mobile; AppBar keeps only the tabs.
    final wide = MediaQuery.sizeOf(context).width >= kBreakWide;

    final general = [
      _accountSection(),
      _libraryFolderSection(),
      _scanFiltersSection(),
      _displaySection(),
      _modeSection(),
      _romTapSection(),
      _themeSection(),
      _dataSection(),
      // Mobile has no sidebar, so surface the version here.
      if (!wide) _aboutSection(),
    ];
    final ui = context.ui;
    return DefaultTabController(
      length: 2,
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
                        UiFocusZoom(child: Tab(text: 'General')),
                        UiFocusZoom(child: Tab(text: 'Systems')),
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
                  // Draws its own cards, so it gets the raw scroll body and the
                  // full, uncapped width rather than a section card.
                  _scroll(
                    double.infinity,
                    SystemSettingsSection(library: widget.library),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
