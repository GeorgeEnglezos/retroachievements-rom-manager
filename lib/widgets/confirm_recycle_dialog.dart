import 'dart:io';

import 'package:flutter/material.dart';

import '../strings.dart';
import 'ui/ui_focusable.dart';

/// True where a delete is permanent (Android has no user-facing trash).
bool get _hardDelete => Platform.isAndroid;

/// Past-tense confirmation for the snackbar after a successful delete.
String get deletedConfirmation => _hardDelete
    ? GameActionStrings.deleted
    : GameActionStrings.movedToRecycleBin;

/// Platform-correct delete-confirmation body. Desktop moves to the Recycle Bin;
/// Android deletes permanently, so the wording must not promise recovery.
/// Pass [files] for a bulk count, or [name] (with [discs] for a multi-disc set).
String deleteConfirmMessage({String? name, int discs = 1, int? files}) {
  final verb = _hardDelete
      ? GameActionStrings.permanentlyDeleteVerb
      : GameActionStrings.moveVerb;
  final suffix = _hardDelete ? '' : GameActionStrings.toRecycleBin;
  if (files != null) {
    return GameActionStrings.deleteFiles(verb, files, suffix);
  }
  if (discs > 1) {
    return GameActionStrings.deleteDiscs(verb, discs, name, suffix);
  }
  return GameActionStrings.deleteOne(verb, name, suffix);
}

/// Shared delete confirmation. True only when Delete is tapped.
Future<bool> confirmRecycleDialog(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        _hardDelete
            ? GameActionStrings.deletePermanentlyTitle
            : GameActionStrings.moveToRecycleBinTitle,
      ),
      content: Text(message),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(GameActionStrings.cancel),
          ),
        ),
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(GameActionStrings.delete),
          ),
        ),
      ],
    ),
  );
  return ok == true;
}
