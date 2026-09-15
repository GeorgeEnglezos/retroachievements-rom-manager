import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ra_image_cache.dart';
import 'package:path/path.dart' as p;
import '../models/rom_result.dart';
import '../services/android_emulators.dart';
import '../services/app_mode.dart';
import '../services/file_actions.dart';
import '../services/icon_service.dart';
import '../services/library.dart';
import '../services/log_service.dart';
import 'confirm_recycle_dialog.dart';
import 'positioned_menu.dart';
import 'ra_image.dart';
import '../services/emulator_store.dart';
import '../services/scan_settings.dart';
import '../services/scraper/scraped_store.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import 'playlist_picker.dart';
import 'set_emulator_dialog.dart';

/// Fallback status icon when a ROM has no box art.
Widget romStatusIcon(RomResult rom) => switch (rom.status) {
      RomStatus.notFetched =>
        const Icon(Icons.cloud_download_outlined, color: Colors.grey),
      RomStatus.checking => const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      RomStatus.supported =>
        const Icon(Icons.check_circle, color: Colors.green),
      RomStatus.unsupported => const Icon(Icons.cancel, color: Colors.red),
      RomStatus.unsupportedFormat =>
        const Icon(Icons.warning_amber, color: Colors.orange),
      RomStatus.error =>
        const Icon(Icons.report_gmailerrorred, color: Colors.blueGrey),
      RomStatus.localOnly =>
        const Icon(Icons.videogame_asset, color: Colors.grey),
      RomStatus.metadataOnly =>
        const Icon(Icons.videogame_asset, color: Colors.blueAccent),
    };

/// Context menu + action handling for a ROM tile, shared by both tiles.
/// [onDismissDuplicate] is only offered when non-null.
class RomActions {
  final RomResult rom;
  final PlaylistStore store;
  final VoidCallback? onDeleted;
  final VoidCallback? onExcluded;
  final VoidCallback? onPlaylistChanged;
  final VoidCallback? onFetch;
  final VoidCallback? onDismissDuplicate;
  final bool isSelected;
  final void Function(String action)? onSelectionAction;
  // All files this tile stands for (a multi-disc set). Null → just [rom].
  // Delete/exclude act on the whole set.
  final List<String>? groupPaths;

  const RomActions({
    required this.rom,
    required this.store,
    this.onDeleted,
    this.onExcluded,
    this.onPlaylistChanged,
    this.onFetch,
    this.onDismissDuplicate,
    this.isSelected = false,
    this.onSelectionAction,
    this.groupPaths,
  });

  List<String> get _paths => groupPaths ?? [rom.filePath];

  Future<void> showContextMenu(BuildContext context, Offset position) async {
    final canOpenRa = rom.status == RomStatus.supported && rom.gameId != null;
    final choice = await showPositionedMenu<String>(context, position, [
        // Beta: only a handful of emulators have been tested end to end.
        _item('play', Icons.play_arrow, 'Play (beta)'),
        if (Platform.isWindows)
          _item('shortcut', Icons.add_link, 'Create desktop shortcut (beta)'),
        if (Platform.isAndroid)
          _item('shortcut', Icons.add_to_home_screen,
              'Add to home screen (beta)'),
        if (!gamingMode) ...[
          _item('reveal', Icons.folder_open, 'Reveal in Explorer'),
          _item('copy', Icons.copy, 'Copy path'),
        ],
        _item('google', Icons.search, 'Search Google'),
        if (canOpenRa) _item('ra', Icons.open_in_new, 'Open RA page'),
        if (rom.status == RomStatus.unsupported)
          _item('why_unsupported', Icons.help_outline, 'Why unsupported?'),
        // Everything below curates or edits the library, which gaming mode
        // exists not to do.
        if (!gamingMode) ...[
          if (rom.duplicateGroupId != null && onDismissDuplicate != null)
            _item('dismiss_dup', Icons.do_not_disturb_on_outlined,
                'Not a duplicate'),
          if (rom.status != RomStatus.checking &&
              !rom.isLocalOnly &&
              onFetch != null)
            rom.status == RomStatus.supported
                ? _item('fetch', Icons.sync, 'Sync progress')
                : _item('fetch', Icons.cloud_download_outlined, 'Fetch'),
        ],
        _item('playlist', Icons.playlist_add, 'Add to playlist…'),
        if (!gamingMode) ...[
          _item('delete', Icons.delete_outline, 'Delete', color: Colors.red),
          _item('exclude', Icons.block, 'Exclude from scans'),
        ],
      ],
    );
    if (choice == null || !context.mounted) return;
    await handle(context, choice);
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Future<void> handle(BuildContext context, String choice) async {
    if (isSelected &&
        onSelectionAction != null &&
        (choice == 'delete' ||
            choice == 'playlist' ||
            choice == 'exclude')) {
      onSelectionAction!(choice);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    void snack(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));

    switch (choice) {
      case 'play':
        await _play(context, snack);
      case 'shortcut':
        if (Platform.isAndroid) {
          await _createAndroidShortcut(context, snack);
        } else {
          await _createShortcut(context, snack);
        }
      case 'reveal':
        if (!await FileActions.revealInExplorer(rom.filePath)) {
          snack("Couldn't reveal file");
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: rom.filePath));
        snack('Path copied');
      case 'fetch':
        onFetch?.call();
      case 'google':
        if (!await FileActions.openUrl(
            FileActions.googleSearchUrl(rom.filePath))) {
          snack("Couldn't open browser");
        }
      case 'ra':
        if (rom.gameId != null &&
            !await FileActions.openUrl(FileActions.raGameUrl(rom.gameId!))) {
          snack("Couldn't open browser");
        }
      case 'why_unsupported':
        await _showWhyUnsupported(context);
      case 'dismiss_dup':
        onDismissDuplicate?.call();
      case 'playlist':
        await PlaylistPicker.show(context, store,
            memberKeyFor(gameId: rom.gameId, filePath: rom.filePath));
        onPlaylistChanged?.call();
      case 'delete':
        await _confirmDelete(context, messenger);
      case 'exclude':
        await ScanSettings.addExcludedFiles(_paths);
        onExcluded?.call();
        snack('Excluded "${rom.fileName}"');
    }
  }

  // Launch via the console's emulator; unknown console -> OS default.
  // No emulator yet -> offer to set one and retry.
  Future<void> _play(BuildContext context, void Function(String) snack) async {
    final consoleId = rom.consoleId ??
        await ScanSettings.consoleIdForFolder(p.dirname(rom.filePath));
    if (consoleId == null) {
      LogService.info('RomActions/launch',
          'Launch ${rom.fileName}: unknown console, using OS default app');
      if (!await FileActions.launchWithDefaultApp(rom.filePath)) {
        snack("Couldn't launch ROM");
      }
      return;
    }
    if (!context.mounted) return;
    if (Platform.isAndroid) {
      await _playAndroid(context, consoleId, snack);
      return;
    }
    final command = await _commandOrPrompt(context, consoleId);
    if (command == null) return;
    LogService.info('RomActions/launch',
        'Launch ${rom.fileName} (console $consoleId) via: $command');
    if (!await FileActions.launchWithTemplate(command, rom.filePath)) {
      LogService.error('RomActions/launch',
          'Launch failed for ${rom.fileName} via: $command');
      snack("Couldn't launch ROM");
    }
  }

  // Android: hand the ROM to the connected app via an intent.
  Future<void> _playAndroid(
      BuildContext context, int consoleId, void Function(String) snack) async {
    var emu = await EmulatorStore.connectedEmulator(consoleId);
    if (emu == null) {
      if (!context.mounted) return;
      if (!await showSetEmulatorDialog(context, consoleId)) return;
      emu = await EmulatorStore.connectedEmulator(consoleId);
    }
    if (emu == null) return;
    LogService.info('RomActions/launch',
        'Launch ${rom.fileName} in ${emu.name} '
        '(pkg=${emu.exePath}, kind=${emu.kindId}, console=$consoleId)');
    final err = await AndroidEmulators.launchRom(
      package: emu.exePath,
      kindId: emu.kindId,
      consoleId: consoleId,
      romPath: rom.filePath,
    );
    if (err != null) {
      LogService.error('RomActions/launch',
          'Launch failed for ${rom.fileName} in ${emu.name} '
          '(pkg=${emu.exePath}): $err');
      snack("Couldn't open in ${emu.name}: $err");
    } else {
      LogService.info('RomActions/launch',
          'Launch OK: ${rom.fileName} in ${emu.name}');
    }
  }

  // Launch command for [consoleId], prompting to set an emulator if missing.
  Future<String?> _commandOrPrompt(BuildContext context, int consoleId) async {
    final existing = await EmulatorStore.commandFor(consoleId);
    if (existing != null) return existing;
    if (!context.mounted) return null;
    final set = await showSetEmulatorDialog(context, consoleId);
    if (!set) return null;
    return EmulatorStore.commandFor(consoleId);
  }

  // Android: pins a home-screen shortcut that relaunches this ROM through the
  // app (re-grants the file URI, rebuilds the intent).
  Future<void> _createAndroidShortcut(
      BuildContext context, void Function(String) snack) async {
    final consoleId = rom.consoleId ??
        await ScanSettings.consoleIdForFolder(p.dirname(rom.filePath));
    if (consoleId == null) {
      snack('Unknown console for this ROM. Set its folder system in Settings.');
      return;
    }
    var emu = await EmulatorStore.connectedEmulator(consoleId);
    if (emu == null) {
      if (!context.mounted) return;
      if (!await showSetEmulatorDialog(context, consoleId)) return;
      emu = await EmulatorStore.connectedEmulator(consoleId);
    }
    if (emu == null) return;
    final err = await AndroidEmulators.createShortcut(
      package: emu.exePath,
      label: p.basenameWithoutExtension(rom.filePath),
      kindId: emu.kindId,
      consoleId: consoleId,
      romPath: rom.filePath,
      iconPath: await _boxArtPng(),
    );
    snack(err == null
        ? 'Shortcut added to your home screen.'
        : "Couldn't create shortcut: $err");
  }

  // Windows-only: Desktop .lnk that opens this ROM in its console's emulator.
  Future<void> _createShortcut(
      BuildContext context, void Function(String) snack) async {
    if (!Platform.isWindows) {
      snack('Desktop shortcuts are only available on Windows.');
      return;
    }
    final consoleId = rom.consoleId ??
        await ScanSettings.consoleIdForFolder(p.dirname(rom.filePath));
    if (consoleId == null) {
      snack('Unknown console for this ROM. Set its folder system in Settings.');
      return;
    }
    if (!context.mounted) return;
    final command = await _commandOrPrompt(context, consoleId);
    if (command == null) return;

    // .lnk target = emulator exe, argument = ROM (re-quoted if spaced).
    final filled = command
        .replaceAll('{file.path}', rom.filePath)
        .replaceAll('{file.dir}', p.dirname(rom.filePath));
    final tokens = FileActions.tokenizeCommand(filled);
    if (tokens.isEmpty) {
      snack("Couldn't build the launch command.");
      return;
    }
    final args = tokens
        .sublist(1)
        .map((t) => t.contains(' ') ? '"$t"' : t)
        .join(' ');
    final lnk = await FileActions.createEmulatorShortcut(
      shortcutName: p.basenameWithoutExtension(rom.filePath),
      targetPath: tokens.first,
      arguments: args,
      iconPath: await _thumbnailIcon(),
    );
    snack(lnk == null
        ? "Couldn't create the shortcut."
        : 'Shortcut created on your Desktop.');
  }

  // Box-art PNG for the Android shortcut icon; null falls back to the app
  // icon. RA/third-party url art first, else imported Skraper art on disk.
  Future<String?> _boxArtPng() async => (await _thumbnailPng())?.path;

  // Thumbnail -> persistent .ico for the shortcut; null falls back to the
  // emulator exe icon. Prefers RA / third-party url art (rom.thumbArt), else
  // imported Skraper art on disk (non-RA consoles like PS3 only have this).
  // Keyed by game id when matched, a path hash otherwise, so every ROM gets a
  // distinct icon.
  Future<String?> _thumbnailIcon() async {
    final png = await _thumbnailPng();
    if (png == null) return null;
    final key = rom.gameId?.toString() ??
        md5.convert(utf8.encode(rom.filePath)).toString();
    try {
      final ico = await IconService.pngToIco(png, key: key);
      return ico?.path;
    } catch (_) {
      return null;
    }
  }

  // Source image for the shortcut icon: RA/third-party url art (downloaded &
  // cached) first, else the imported Skraper thumbnail already on disk.
  Future<File?> _thumbnailPng() async {
    final art = rom.thumbArt;
    if (art != null) {
      try {
        return await raCacheManager.getSingleFile(raImageUrl(art));
      } catch (_) {
        return null;
      }
    }
    await ScrapedStore.instance.load();
    final scraped = ScrapedStore.instance.get(rom.filePath)?.thumbPath;
    if (scraped == null) return null;
    final f = File(scraped);
    return f.existsSync() ? f : null;
  }

  // Explains no-match causes and links the console's supported-games list.
  Future<void> _showWhyUnsupported(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why unsupported?'),
        content: const Text(
          "RetroAchievements didn't recognise this file's hash. Common causes:\n\n"
          "• Wrong region or revision (e.g. an EU ROM where RA expects USA).\n"
          "• A bad dump or hacked/translated ROM; RA needs a known-good redump.\n"
          "• The game has no achievement set yet.\n"
          "• A patch (IPS/BPS) needs applying first.\n\n"
          "Open this console's supported list on RetroAchievements to compare "
          "the exact titles and hashes RA accepts.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open RA supported list'),
          ),
        ],
      ),
    );
    if (open != true) return;
    if (!await FileActions.openUrl(
        FileActions.raSupportedListUrl(rom.consoleId))) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't open browser")));
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ScaffoldMessengerState messenger) async {
    final paths = _paths;
    final prompt =
        deleteConfirmMessage(name: rom.fileName, discs: paths.length);
    final ok = await confirmRecycleDialog(context, prompt);
    if (!ok) return;
    var any = false;
    for (final path in paths) {
      if (await Library.instance.deleteRom(path)) any = true;
    }
    if (any) {
      onDeleted?.call();
      messenger
          .showSnackBar(SnackBar(content: Text(deletedConfirmation)));
    } else {
      messenger
          .showSnackBar(const SnackBar(content: Text("Couldn't delete file")));
    }
  }
}
