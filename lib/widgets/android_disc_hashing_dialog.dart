import 'package:flutter/material.dart';
import 'ui/ui_focusable.dart';
import '../strings.dart';

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
      title: const Text(FetchStrings.androidDiscTitle),
      content: const Text(FetchStrings.androidDiscBody),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(FetchStrings.okButton),
          ),
        ),
      ],
    ),
  );
}
