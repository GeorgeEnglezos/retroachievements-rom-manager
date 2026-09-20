import 'dart:io';

import 'package:flutter/material.dart';
import 'ui/ui_focusable.dart';

/// True where a delete is permanent (Android has no user-facing trash).
bool get _hardDelete => Platform.isAndroid;

/// Past-tense confirmation for the snackbar after a successful delete.
String get deletedConfirmation =>
    _hardDelete ? 'Deleted' : 'Moved to Recycle Bin';

/// Platform-correct delete-confirmation body. Desktop moves to the Recycle Bin;
/// Android deletes permanently, so the wording must not promise recovery.
/// Pass [files] for a bulk count, or [name] (with [discs] for a multi-disc set).
String deleteConfirmMessage({String? name, int discs = 1, int? files}) {
  final verb = _hardDelete ? 'Permanently delete' : 'Move';
  final suffix = _hardDelete ? '' : ' to the Recycle Bin';
  if (files != null) {
    return '$verb $files file${files == 1 ? '' : 's'}$suffix?';
  }
  if (discs > 1) {
    return "$verb all $discs discs of '$name'$suffix?";
  }
  return "$verb '$name'$suffix?";
}

/// Shared delete confirmation. True only when Delete is tapped.
Future<bool> confirmRecycleDialog(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_hardDelete ? 'Delete permanently?' : 'Move to Recycle Bin?'),
      content: Text(message),
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
            child: const Text('Delete'),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}
