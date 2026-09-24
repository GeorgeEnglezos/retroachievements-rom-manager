import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/log_service.dart';
import 'ui/ui_focusable.dart';

/// Confirms, asks for a backup zip and restores it, then blocks the UI until
/// the app is restarted. Used by Settings and the setup wizard. Lives in
/// widgets/ (not services/) because it drives dialogs and SnackBars.
Future<void> restoreBackup(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restore from backup?'),
      content: const Text(
        'This replaces everything you have now: scan results, imported '
        'metadata, cached artwork and settings. Your RetroAchievements API '
        'key is not in a backup, so the one you have now is kept. Restart '
        'the app afterwards.',
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  void toast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  try {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose a backup zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = res?.files.single.path;
    if (path == null) return; // cancelled
    await const BackupService().restore(path);
    if (!context.mounted) return;
    // Every in-memory store still holds the pre-restore data, and the next
    // save would write it back over the files just restored. Block the UI
    // until the app is restarted rather than trust a dismissable toast.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Restored'),
        content: Text(
          'Close and reopen the app to load the backup. Using '
          'it before then can overwrite what was just restored.',
        ),
      ),
    );
  } on FormatException {
    toast('That zip is not a RARM backup.');
  } catch (e) {
    LogService.error('Settings/restore', 'restore failed', err: e);
    toast('Restore failed, see the log for details.');
  }
}
