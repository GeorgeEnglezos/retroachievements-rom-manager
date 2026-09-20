import 'package:flutter/material.dart';
import 'ui/ui_focusable.dart';

// Shown at most once per app session; bulk fetch can hit many GC/Wii discs and
// we don't want to spam a dialog per file.
bool _shown = false;

/// One-time alert: RVZ/WIA dumps can't be hashed on Android yet (their per-block
/// codecs aren't decoded on-device), so they can't be matched to RA. CISO, WBFS
/// and GCZ now hash on-device. Safe to call repeatedly; only the first call in a
/// session shows the dialog.
Future<void> showAndroidDiscHashingUnsupported(BuildContext context) async {
  if (_shown) return;
  _shown = true;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('GameCube & Wii on Android'),
      content: const Text(
        "Compressed .rvz and .wia dumps can't be hashed on Android yet, so they "
        "can't be matched to RetroAchievements. On-device hashing for these "
        'formats is under development.\n\n'
        'For now, convert them to .iso (or .ciso/.wbfs/.gcz, which do hash on '
        'Android), or hash them on the desktop version.',
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );
}
