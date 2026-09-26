import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/log_service.dart';
import 'ui/ui_focusable.dart';
import '../strings.dart';

/// Confirms, asks for a backup zip and restores it, then blocks the UI until
/// the app is restarted. Used by Settings and the setup wizard. Lives in
/// widgets/ (not services/) because it drives dialogs and SnackBars.
Future<void> restoreBackup(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(WizardStrings.restoreConfirmTitle),
      content: const Text(WizardStrings.restoreConfirmBody),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ShellStrings.cancel),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(WizardStrings.restoreButton),
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
      dialogTitle: WizardStrings.chooseBackupZip,
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
        title: Text(WizardStrings.restoredTitle),
        content: Text(WizardStrings.restoredBody),
      ),
    );
  } on FormatException {
    toast(WizardStrings.notABackup);
  } catch (e) {
    LogService.error('Settings/restore', 'restore failed', err: e);
    toast(WizardStrings.restoreFailed);
  }
}
