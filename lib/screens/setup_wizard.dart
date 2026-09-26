import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/console_map.dart';
import '../services/credentials.dart';
import '../services/library_folder.dart';
import '../services/pref_keys.dart';
import '../services/ra_service.dart';
import '../services/rom_file_lister.dart';
import '../services/scan_settings.dart';
import '../services/scraper/gamelist_importer.dart';
import '../services/scraper/scraped_store.dart';
import '../strings.dart';
import '../theme/ui_tokens.dart';
import '../widgets/app_mode_toggle.dart';
import '../widgets/pick_library_folder.dart';
import '../widgets/restore_backup.dart';
import '../widgets/theme_picker.dart';
import '../widgets/ui_scale_control.dart';
import '../widgets/ui/ui_button.dart';
import '../widgets/ui/ui_dropdown.dart';
import 'home_screen.dart';
import '../widgets/ui/ui_focusable.dart';

/// Where RA shows a user their Web API key. Their API docs still link the older
/// controlpanel.php; this is the current settings page it lands on.
const kRaApiKeyUrl = 'https://retroachievements.org/settings?tab=applications';

/// Verifies a username/key pair against RA and returns the account's canonical
/// avatar path, or throws when the pair is rejected.
typedef CredentialVerifier =
    Future<String> Function(String username, String apiKey);

/// Finds scrape sources under a root, matches them to [romPaths], and stores
/// what matched.
typedef ScrapedImporter =
    Future<ImportResult> Function(String root, Set<String> romPaths);

/// Detection and parsing run on a background isolate; only the matched games
/// come back to be stored.
Future<ImportResult> _importAndStore(String root, Set<String> romPaths) async {
  final result = await importFromDirectory(root, romPaths);
  await ScrapedStore.instance.putAll(result.matched);
  return result;
}

/// Opens setup as a modal. Tapping outside does not close it; a half-finished
/// setup is left by Skip, which still marks it handled.
Future<void> showSetupWizard(
  BuildContext context, [
  SetupWizard wizard = const SetupWizard(),
]) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => wizard,
);

/// First-run setup. Opened over [AppShell] until [PrefKeys.setupDone] is set,
/// and reachable again from Settings.
class SetupWizard extends StatefulWidget {
  /// Injectable for tests; defaults to a real RA profile lookup.
  final CredentialVerifier? verifyCredentials;

  /// Injectable for tests: skips the system folder picker.
  final String? initialFolder;

  /// Injectable for tests: opens straight on a given step.
  final int initialStep;

  /// Injectable for tests; defaults to a real scrape-source import.
  final ScrapedImporter? importScrapedData;

  const SetupWizard({
    super.key,
    this.verifyCredentials,
    this.initialFolder,
    this.initialStep = 0,
    this.importScrapedData,
  });

  @override
  State<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends State<SetupWizard> {
  late final _pageCtrl = PageController(initialPage: widget.initialStep);
  late int _step = widget.initialStep;
  VerifiedCredentials? _verifiedCredentials;
  String? _folder;
  bool _finishing = false;

  static final _lastStep = _stepNames.length - 1;

  // Real verification hits RA's profile endpoint through RaService, which
  // already sets the User-Agent the API requires.
  CredentialVerifier get _verify =>
      widget.verifyCredentials ??
      (username, apiKey) =>
          RaService(username: username, apiKey: apiKey).getUserPicPath();

  // Step 1 (credentials) must verify before the user can move on; a wrong key
  // is the one setup mistake that fails silently everywhere else. Step 2 needs
  // a folder; there is nothing to scan without one.
  bool get _canContinue => switch (_step) {
    1 => _verifiedCredentials != null,
    2 => _folder != null,
    _ => _step < _lastStep,
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step >= _lastStep) return;
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) return;
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  // Marks setup handled and closes the modal onto the shell underneath.
  // Whatever earlier steps saved stays saved; skipping abandons the remaining
  // steps, not the finished ones.
  Future<void> _finish({bool startScan = false}) async {
    if (_finishing) return; // a second tap during the route transition
    _finishing = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.setupDone, true);
    if (!mounted) return;
    if (startScan) firstScanRequest.value = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final size = MediaQuery.sizeOf(context);
    // Phones get the whole screen, like the detail modal; the folder list
    // needs the room.
    final full = size.width < kBreakWide;
    return Dialog(
      backgroundColor: ui.background,
      insetPadding: EdgeInsets.all(full ? 8 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: full ? double.infinity : size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: UiFocusZoom(
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      WizardStrings.skipSetup,
                      style: ui.labelCaps.copyWith(color: ui.muted),
                    ),
                  ),
                ),
              ),
              _StepBar(current: _step),
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  // Steps gate each other (credentials must verify), so
                  // swiping past them is not allowed.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    const _WelcomeStep(),
                    _CredentialsStep(
                      verify: _verify,
                      verified: _verifiedCredentials,
                      onVerifiedChanged: (v) =>
                          setState(() => _verifiedCredentials = v),
                    ),
                    _FolderStep(
                      initialFolder: widget.initialFolder,
                      importScrapedData:
                          widget.importScrapedData ?? _importAndStore,
                      onFolderChanged: (f) => setState(() => _folder = f),
                    ),
                    const _StyleStep(),
                    const _FirstScanStep(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  UiButton(
                    label: WizardStrings.backButton,
                    variant: UiButtonVariant.secondary,
                    onPressed: _step == 0 ? null : _back,
                  ),
                  if (_step < _lastStep)
                    UiButton(
                      label: WizardStrings.continueButton,
                      onPressed: _canContinue ? _next : null,
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        UiButton(
                          label: WizardStrings.laterButton,
                          variant: UiButtonVariant.secondary,
                          onPressed: _finish,
                        ),
                        UiButton(
                          label: WizardStrings.startScanButton,
                          onPressed: () => _finish(startScan: true),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labels for [_StepBar], one per page, in order.
const _stepNames = [
  WizardStrings.stepWelcome,
  WizardStrings.stepAccount,
  ShellStrings.navLibrary,
  WizardStrings.stepStyle,
  WizardStrings.scan,
];

/// Named progress row: done steps filled, the current one ringed, the rest
/// hollow, joined by a line that fills as the user moves through.
class _StepBar extends StatelessWidget {
  final int current;

  const _StepBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final last = _stepNames.length - 1;
    Widget line(bool visible, bool reached) => Expanded(
      child: Container(
        height: 2,
        color: !visible
            ? Colors.transparent
            : reached
            ? ui.accent
            : ui.border,
      ),
    );
    return Semantics(
      label: WizardStrings.stepSemantics(
        current + 1,
        last + 1,
        _stepNames[current],
      ),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i <= last; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      line(i > 0, i <= current),
                      Container(
                        width: 14,
                        height: 14,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < current ? ui.accent : ui.background,
                          border: Border.all(
                            color: i <= current ? ui.accent : ui.border,
                            width: 2,
                          ),
                        ),
                        child: i == current
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ui.accent,
                                ),
                              )
                            : null,
                      ),
                      line(i < last, i < current),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _stepNames[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: ui.labelCaps.copyWith(
                      color: i == current ? ui.text : ui.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(WizardStrings.welcomeTitle, style: ui.display),
          const SizedBox(height: 16),
          Text(WizardStrings.welcomeBody, style: ui.body),
          const SizedBox(height: 12),
          Text(WizardStrings.welcomeSetupCovers, style: ui.body),
          const SizedBox(height: 24),
          Text(
            WizardStrings.welcomeRestoreHint,
            style: ui.body.copyWith(color: ui.muted),
          ),
          const SizedBox(height: 8),
          UiButton(
            label: WizardStrings.restoreFromBackupButton,
            icon: Icons.restore,
            variant: UiButtonVariant.secondary,
            onPressed: () => restoreBackup(context),
          ),
        ],
      ),
    );
  }
}

/// Mode, theme and UI scale: the choices that change how every later screen
/// looks. Each writes its setting straight away, like Settings does.
class _StyleStep extends StatelessWidget {
  const _StyleStep();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final label = ui.labelCaps.copyWith(color: ui.muted);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(WizardStrings.styleTitle, style: ui.display),
          const SizedBox(height: 12),
          Text(WizardStrings.styleBody, style: ui.body),
          const SizedBox(height: 24),
          Text(WizardStrings.modeLabel, style: label),
          const SizedBox(height: 4),
          Text(AppearanceStrings.modeHelp, style: ui.body),
          const SizedBox(height: 8),
          const AppModeToggle(),
          const SizedBox(height: 24),
          Text(WizardStrings.themeLabel, style: label),
          const SizedBox(height: 8),
          const ThemePicker(),
          const SizedBox(height: 24),
          Text(WizardStrings.uiScaleLabel, style: label),
          const SizedBox(height: 8),
          const UiScaleControl(),
        ],
      ),
    );
  }
}

/// A username/key pair that passed the live check, plus the avatar path RA
/// returned for it.
typedef VerifiedCredentials = ({
  String username,
  String apiKey,
  String avatarPath,
});

class _CredentialsStep extends StatefulWidget {
  /// The pair that last passed. Owned by the wizard, not this step: the
  /// PageView discards this step's state once its fields lose focus, so
  /// step-local verification would silently come back as "still verified".
  final VerifiedCredentials? verified;

  /// Fires with the new pair on success, and with null once the typed text
  /// stops matching [verified].
  final ValueChanged<VerifiedCredentials?> onVerifiedChanged;
  final CredentialVerifier verify;

  const _CredentialsStep({
    required this.verified,
    required this.onVerifiedChanged,
    required this.verify,
  });

  @override
  State<_CredentialsStep> createState() => _CredentialsStepState();
}

class _CredentialsStepState extends State<_CredentialsStep> {
  final _usernameCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  // Verification is derived from the text, never stored here; that is what
  // makes it survive this step being rebuilt.
  bool get _matchesVerified {
    final v = widget.verified;
    return v != null &&
        _usernameCtrl.text.trim() == v.username &&
        _apiKeyCtrl.text.trim() == v.apiKey;
  }

  @override
  void initState() {
    super.initState();
    // Restore the verified pair *before* listening: filling the fields one at
    // a time looks like a mismatch in between, and reporting that would call
    // setState on the wizard mid-build.
    final verified = widget.verified;
    if (verified != null) {
      _usernameCtrl.text = verified.username;
      _apiKeyCtrl.text = verified.apiKey;
    }
    _usernameCtrl.addListener(_onEdited);
    _apiKeyCtrl.addListener(_onEdited);
    if (verified == null) _prefillFromSaved();
  }

  // Editing either field after a successful check means the confirmation on
  // screen no longer describes what is typed, so drop back to unverified.
  void _onEdited() {
    if (widget.verified == null) return;
    if (_matchesVerified) return;
    widget.onVerifiedChanged(null);
  }

  // First visit only: show whatever Settings already had saved. Nothing is
  // treated as verified until the live check passes.
  Future<void> _prefillFromSaved() async {
    final creds = await savedCredentials();
    if (creds == null || !mounted) return;
    setState(() {
      _usernameCtrl.text = creds.$1;
      _apiKeyCtrl.text = creds.$2;
    });
  }

  @override
  void dispose() {
    _usernameCtrl.removeListener(_onEdited);
    _apiKeyCtrl.removeListener(_onEdited);
    _usernameCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _openKeyPage() async {
    // externalApplication: the key lives behind the user's RA login, which is
    // in their browser, not an in-app webview.
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(kRaApiKeyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false; // no handler registered for http on this desktop
    }
    if (opened || !mounted) return;
    // Only surface the address when the browser didn't open; otherwise it is
    // noise on a step that already has two fields to fill in.
    await Clipboard.setData(const ClipboardData(text: kRaApiKeyUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ShellStrings.browserOpenFailed(kRaApiKeyUrl)),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _verify() async {
    final username = _usernameCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();
    if (username.isEmpty || apiKey.isEmpty) {
      setState(() => _error = WizardStrings.credentialsMissing);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final path = await widget.verify(username, apiKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.raUsername, username);
      await saveApiKey(apiKey);
      await prefs.setString(PrefKeys.raAvatarPath, path);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onVerifiedChanged((
        username: username,
        apiKey: apiKey,
        avatarPath: path,
      ));
    } catch (_) {
      if (!mounted) return;
      // Nothing is saved on failure, so a bad key can't silently break every
      // later fetch.
      setState(() {
        _busy = false;
        _error = WizardStrings.credentialsRejected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(WizardStrings.accountTitle, style: ui.display),
          const SizedBox(height: 12),
          Text(WizardStrings.accountBody, style: ui.body),
          const SizedBox(height: 12),
          UiButton(
            icon: Icons.open_in_new,
            label: WizardStrings.getApiKeyButton,
            variant: UiButtonVariant.secondary,
            onPressed: _openKeyPage,
          ),
          const SizedBox(height: 16),
          UiFocusZoom(
            child: TextField(
              key: const Key('setup-username'),
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: WizardStrings.usernameLabel,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          UiFocusZoom(
            child: TextField(
              key: const Key('setup-apikey'),
              controller: _apiKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: WizardStrings.apiKeyLabel,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          UiButton(
            label: _busy ? WizardStrings.checkingButton : WizardStrings.verifyButton,
            onPressed: _busy ? null : _verify,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: ui.body.copyWith(color: ui.warning)),
          ],
          if (_matchesVerified) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: ui.supported),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    WizardStrings.signedInAs(widget.verified!.username),
                    style: ui.body.copyWith(color: ui.supported),
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

/// What the folder step found alongside the ROMs. Silent when there was
/// nothing to find; a library with no scraped data should not be told so.
class _ScrapedSummary extends StatelessWidget {
  final bool importing;
  final ImportResult? result;

  const _ScrapedSummary({required this.importing, required this.result});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    if (importing) {
      return Text(
        WizardStrings.scrapedLooking,
        style: ui.body.copyWith(color: ui.muted),
      );
    }
    final r = result;
    if (r == null || r.matched.isEmpty) return const SizedBox.shrink();
    final games = r.matched.length;
    final systems = r.systemCount;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.image_search, size: 18, color: ui.supported),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                WizardStrings.scrapedFound(games, systems),
                style: ui.body.copyWith(color: ui.supported),
              ),
              const SizedBox(height: 4),
              Text(
                WizardStrings.scrapedExplainer,
                style: ui.body.copyWith(color: ui.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Width of the folder list's checkbox column, shared by the rows and the
/// header above them so the label sits over the controls it names.
const _scanColumnWidth = 40.0;

/// Auto-detect plus every hashable console, name-sorted, for the row dropdowns.
final _consoleItems = <UiDropdownItem<int?>>[
  (value: null, label: WizardStrings.autoDetect),
  ...(ConsoleMap.consoleNames.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value)))
      .map((e) => (value: e.key as int?, label: e.value)),
];

/// One subfolder row's resolved state. `romCount` is null until its walk lands,
/// and stays null for excluded folders; they are never walked.
typedef _SystemRow = ({
  String name,
  String path,
  int? consoleId,
  int? romCount,
  bool excluded,
});

class _FolderStep extends StatefulWidget {
  /// Called with the chosen root so the shell can unlock Continue.
  final ValueChanged<String?> onFolderChanged;
  final String? initialFolder;
  final ScrapedImporter importScrapedData;

  const _FolderStep({
    required this.onFolderChanged,
    required this.importScrapedData,
    this.initialFolder,
  });

  @override
  State<_FolderStep> createState() => _FolderStepState();
}

class _FolderStepState extends State<_FolderStep> {
  String? _root;
  List<_SystemRow> _rows = [];

  // Bumped per load so a slow walk that lost the race can't publish its rows
  // over a newer pick's.
  int _loadGeneration = 0;

  // Every ROM the count walk saw, reused to match scraped data against.
  final _romPaths = <String>{};

  bool _importing = false;
  ImportResult? _imported;

  @override
  void initState() {
    super.initState();
    // Re-running setup shows the folder already in use.
    _root = widget.initialFolder ?? libraryFolderListenable.value;
    if (_root != null) _loadRows(_root!);
  }

  Future<void> _pick() async {
    final picked = await pickLibraryFolder(context);
    if (picked == null || !mounted) return;
    setState(() => _root = picked);
    await _loadRows(picked);
  }

  // Names and detected consoles land immediately; ROM counts are filled in per
  // folder afterwards so a large library never stalls the list.
  Future<void> _loadRows(String root) async {
    final generation = ++_loadGeneration;
    final ignored = (await ScanSettings.ignoredFolders())
        .map((e) => e.toLowerCase())
        .toSet();
    final dirs = <Directory>[];
    final rootDir = Directory(root);
    if (await rootDir.exists()) {
      await for (final entity in rootDir.list()) {
        if (entity is! Directory) continue;
        // Excluded folders are listed too, greyed out; otherwise excluding one
        // makes it vanish with no way to change your mind.
        dirs.add(entity);
      }
    }
    dirs.sort(
      (a, b) => p
          .basename(a.path)
          .toLowerCase()
          .compareTo(p.basename(b.path).toLowerCase()),
    );

    final rows = <_SystemRow>[];
    for (final dir in dirs) {
      final name = p.basename(dir.path);
      rows.add((
        name: name,
        path: dir.path,
        consoleId: await ScanSettings.consoleIdForFolder(dir.path),
        romCount: null,
        excluded: ignored.contains(name.toLowerCase()),
      ));
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _rows = rows;
      // A different root means different ROMs and a different scrape.
      _romPaths.clear();
      _imported = null;
    });
    widget.onFolderChanged(root);
    _countRoms(root, generation);
  }

  Future<void> _countRoms(String root, int generation) async {
    final rows = _rows;
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].excluded) continue; // not scanned, so not worth walking
      if (!await _countFolder(i, rows)) return; // list replaced under us
    }
    await _importScraped(root, generation);
  }

  /// Walks one folder and writes its ROM count back. Returns false when the
  /// row list was replaced mid-walk, so callers can stop.
  Future<bool> _countFolder(int index, List<_SystemRow> rows) async {
    final extensions = await ScanSettings.enabledExtensions();
    final files = await listRomFiles([rows[index].path], extensions);
    _romPaths.addAll(files.map((f) => f.path));
    if (!mounted || !identical(rows, _rows)) return false;
    // Re-read: the user may have corrected this row's console, or excluded it
    // again, while its files were being walked. Writing back the pre-await
    // snapshot would silently revert that.
    final row = _rows[index];
    if (row.excluded) return true;
    setState(() {
      _rows[index] = (
        name: row.name,
        path: row.path,
        consoleId: row.consoleId,
        romCount: files.length,
        excluded: false,
      );
    });
    return true;
  }

  // Skraper and friends leave gamelist.xml / .dat files beside the ROMs. Import
  // them now that every ROM path is known; matching needs paths, not a
  // finished scan, so this does not have to wait for the first RA sweep. What
  // lands here only ever fills gaps RA leaves; RA wins wherever it has data.
  Future<void> _importScraped(String root, int generation) async {
    if (_romPaths.isEmpty) return;
    setState(() => _importing = true);
    ImportResult? result;
    try {
      result = await widget.importScrapedData(root, Set.of(_romPaths));
    } catch (_) {
      // Scraped data is a bonus; a bad file must not derail setup.
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _importing = false;
      _imported = result;
    });
  }

  // Excluding hides a folder from every scan (Settings calls the same list
  // "ignored folders"). Reversible here, so a mis-click costs nothing.
  Future<void> _setExcluded(int index, bool excluded) async {
    final rows = _rows;
    final row = rows[index];
    if (excluded) {
      await ScanSettings.addIgnoredFolder(row.name);
    } else {
      await ScanSettings.removeIgnoredFolder(row.name);
    }
    if (!mounted || !identical(rows, _rows)) return;
    final current = _rows[index];
    setState(() {
      _rows[index] = (
        name: current.name,
        path: current.path,
        consoleId: current.consoleId,
        romCount: excluded ? null : current.romCount,
        excluded: excluded,
      );
    });
    if (excluded) {
      // Drop its files so a later import cannot match against a folder the
      // user just excluded.
      _romPaths.removeWhere((f) => p.isWithin(row.path, f));
      return;
    }
    // Re-including has to walk the folder again: its count was cleared on the
    // way out, and without this the row sits on "counting..." with nothing
    // actually counting.
    await _countFolder(index, rows);
  }

  Future<void> _setConsole(int index, int? consoleId) async {
    final rows = _rows;
    await ScanSettings.setFolderConsoleOverride(rows[index].name, consoleId);
    final resolved = await ScanSettings.consoleIdForFolder(rows[index].path);
    if (!mounted || !identical(rows, _rows)) return;
    // Re-read: this row's ROM count may have landed while the override was
    // being written, and the pre-await snapshot would reset it to "counting…".
    final row = _rows[index];
    setState(() {
      _rows[index] = (
        name: row.name,
        path: row.path,
        consoleId: resolved,
        romCount: row.romCount,
        excluded: row.excluded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(WizardStrings.folderTitle, style: ui.display),
        const SizedBox(height: 12),
        Text(WizardStrings.folderBody, style: ui.body),
        const SizedBox(height: 16),
        Row(
          children: [
            UiButton(
              icon: Icons.folder_open,
              label: _root == null
                  ? WizardStrings.pickFolderButton
                  : WizardStrings.changeFolderButton,
              onPressed: _pick,
            ),
            if (_root != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _root!,
                  style: ui.body.copyWith(color: ui.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (_importing || _imported != null) ...[
          const SizedBox(height: 12),
          _ScrapedSummary(importing: _importing, result: _imported),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _rows.isEmpty
              ? Text(
                  _root == null
                      ? WizardStrings.noFolderPicked
                      : WizardStrings.noSubfolders,
                  style: ui.body.copyWith(color: ui.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stated once, so the checkbox column does not have to be
                    // guessed at from the control alone.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _scanColumnWidth,
                            child: Text(
                              WizardStrings.scan,
                              textAlign: TextAlign.center,
                              style: ui.labelCaps.copyWith(color: ui.muted),
                            ),
                          ),
                          Text(
                            WizardStrings.folderColumn,
                            style: ui.labelCaps.copyWith(color: ui.muted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _folderList(ui)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _folderList(UiTokens ui) => ListView.builder(
    itemCount: _rows.length,
    itemBuilder: (_, i) {
      final row = _rows[i];
      final count = row.romCount;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: _scanColumnWidth,
              child: UiFocusZoom(
                child: Checkbox(
                  key: Key('exclude-${row.name}'),
                  value: !row.excluded,
                  activeColor: ui.accent,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => _setExcluded(i, v != true),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: row.excluded
                        ? ui.body.copyWith(
                            color: ui.muted,
                            decoration: TextDecoration.lineThrough,
                          )
                        : ui.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    row.excluded
                        ? WizardStrings.excludedFolder
                        : count == null
                        ? WizardStrings.counting
                        : WizardStrings.romCount(count),
                    style: ui.body.copyWith(color: ui.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            UiDropdown<int?>(
              key: Key('console-${row.name}'),
              value: row.consoleId,
              items: _consoleItems,
              enabled: !row.excluded,
              onChanged: (v) => _setConsole(i, v),
            ),
          ],
        ),
      );
    },
  );
}

class _FirstScanStep extends StatelessWidget {
  const _FirstScanStep();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(WizardStrings.readyTitle, style: ui.display),
        const SizedBox(height: 12),
        Text(WizardStrings.readyBody, style: ui.body),
        const SizedBox(height: 12),
        Text(WizardStrings.readyDuration, style: ui.body),
      ],
    );
  }
}
