import 'package:flutter/material.dart';

// Shown at most once per app session; bulk fetch can hit many GC/Wii discs and
// we don't want to spam a dialog per file.
bool _shown = false;

/// One-time alert: compressed GameCube/Wii dumps can't be hashed on Android yet
/// (no on-device disc decompressor), so they can't be matched to RA. Safe to
/// call repeatedly; only the first call in a session shows the dialog.
Future<void> showAndroidDiscHashingUnsupported(BuildContext context) async {
  if (_shown) return;
  _shown = true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('GameCube & Wii on Android'),
      content: const Text(
        "Compressed GameCube and Wii dumps (.rvz, .wbfs, …) can't be hashed on "
        "Android yet, so they can't be matched to RetroAchievements. On-device "
        'disc hashing is under development.\n\n'
        'For now, convert them to .iso, or hash them on the desktop version.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
