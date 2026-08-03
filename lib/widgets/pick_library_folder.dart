import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/library_folder.dart';
import '../services/log_service.dart';
import '../services/pref_keys.dart';
import '../services/storage_permission.dart';

/// Prompts for a ROM folder, persists it, and publishes it to
/// [libraryFolderListenable]. Returns the picked path, or null if cancelled or
/// blocked on permissions. Lives in widgets/ (not services/) because it drives
/// UI: a system picker dialog and a SnackBar.
Future<String?> pickLibraryFolder(BuildContext context) async {
  // Android 11+ needs MANAGE_EXTERNAL_STORAGE for raw-path scans;
  // hasAccess() short-circuits true pre-Android-11 and on non-Android.
  if (Platform.isAndroid && !await StoragePermission.hasAccess()) {
    await StoragePermission.openSettings();
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grant "All files access", then tap Pick folder again.'),
      ),
    );
    return null;
  }
  final result = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Select ROM folder',
  );
  if (result == null) return null;
  LogService.info('LibraryFolder/pick', 'Selected root folder: $result');
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefKeys.lastFolder, result);
  libraryFolderListenable.value = result;
  return result;
}
