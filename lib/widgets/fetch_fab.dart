import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pref_keys.dart';
import '../services/scan_progress.dart';
import 'ra_image.dart';

/// The one entry point for a fetch run, shared by the home screen and the
/// folder view so both look and behave the same. Shows the user's RA avatar
/// once it resolves, a refresh icon until then, and disables itself while any
/// run holds the progress bar (two runs would write the same index).
class FetchFab extends StatefulWidget {
  final VoidCallback onPressed;

  const FetchFab({super.key, required this.onPressed});

  @override
  State<FetchFab> createState() => _FetchFabState();
}

class _FetchFabState extends State<FetchFab> {
  String? _avatarPath;
  int? _avatarVersion;

  @override
  void initState() {
    super.initState();
    raAvatarListenable.addListener(_loadAvatar);
    _loadAvatar();
  }

  @override
  void dispose() {
    raAvatarListenable.removeListener(_loadAvatar);
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    // Home refreshes these from RA in the background; read whatever it cached.
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(PrefKeys.raAvatarPath);
    final version = prefs.getInt(PrefKeys.raAvatarVersion);
    if (mounted) {
      setState(() {
        _avatarPath = path;
        _avatarVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ScanProgress.instance,
      builder: (context, _) {
        final busy = ScanProgress.instance.running;
        final path = _avatarPath;
        return FloatingActionButton(
          heroTag: 'updateLibrary',
          tooltip: 'Update library (rescan & sync progress)',
          onPressed: busy ? null : widget.onPressed,
          child: path == null
              ? const Icon(Icons.refresh)
              : ClipOval(
                  child: RaImage(
                    url: raAvatarUrl(path, version: _avatarVersion),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    error: Image.asset('assets/ra-icon.webp',
                        width: 40, height: 40),
                  ),
                ),
        );
      },
    );
  }
}
