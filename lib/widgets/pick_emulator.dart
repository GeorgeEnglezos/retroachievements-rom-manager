import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/emulator_catalog.dart';
import '../services/emulator_store.dart';
import 'app_picker_dialog.dart';

/// Picks a new emulator: Android chooses an installed app, desktop browses for
/// an exe. Detects the emulator kind and defaults the name. Returns null on
/// cancel; a desktop picker failure shows a snackbar and returns null.
Future<Emulator?> pickNewEmulator(BuildContext context,
    {String? dialogTitle}) async {
  if (Platform.isAndroid) {
    final app = await showAppPickerDialog(context);
    if (app == null) return null;
    return Emulator(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: app.label,
      exePath: app.package,
      kindId: EmulatorCatalog.detectKindFromPackage(app.package),
    );
  }
  String? exe;
  try {
    final res = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle ?? 'Choose the emulator executable');
    exe = (res != null && res.files.isNotEmpty) ? res.files.first.path : null;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open file picker")));
    }
    return null;
  }
  if (exe == null) return null;
  final kindId = EmulatorCatalog.detectKind(exe);
  final kind = EmulatorCatalog.kindById(kindId);
  return Emulator(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: kind?.name ?? p.basenameWithoutExtension(exe),
    exePath: exe,
    kindId: kindId,
  );
}

/// Desktop: browses for the folder to search for emulators. Null on cancel, or
/// when the picker fails (snackbar shown).
Future<String?> pickEmulatorFolder(BuildContext context) async {
  try {
    return await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select the folder your emulators live in');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open folder picker")));
    }
    return null;
  }
}
