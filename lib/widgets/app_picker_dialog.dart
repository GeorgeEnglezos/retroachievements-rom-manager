import 'package:flutter/material.dart';

import '../services/android_emulators.dart';

/// Android app picker: lists installed launchable apps (known emulators first)
/// and returns the chosen one, or null on cancel. Android-only.
Future<InstalledApp?> showAppPickerDialog(BuildContext context) {
  return showDialog<InstalledApp>(
    context: context,
    builder: (_) => const _AppPickerDialog(),
  );
}

class _AppPickerDialog extends StatefulWidget {
  const _AppPickerDialog();

  @override
  State<_AppPickerDialog> createState() => _AppPickerDialogState();
}

class _AppPickerDialogState extends State<_AppPickerDialog> {
  List<InstalledApp>? _apps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await AndroidEmulators.installedApps();
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    return AlertDialog(
      title: const Text('Pick an emulator app'),
      content: SizedBox(
        width: double.maxFinite,
        child: apps == null
            ? const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()))
            : apps.isEmpty
                ? const Text('No apps found.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: apps.length,
                    itemBuilder: (_, i) {
                      final app = apps[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(app.known
                            ? Icons.videogame_asset
                            : Icons.android),
                        title: Text(app.label),
                        subtitle: Text(app.package,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, app),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
