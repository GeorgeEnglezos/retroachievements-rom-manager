import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../services/credentials.dart';

/// Returns saved RA credentials, or null after a "set credentials" snackbar.
Future<(String, String)?> requireCredentials(BuildContext context) async {
  final creds = await savedCredentials();
  if (creds != null) return creds;
  if (!context.mounted) return null;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content:
          const Text('Set your RetroAchievements credentials in Settings first.'),
      action: SnackBarAction(
        label: 'Settings',
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ),
  );
  return null;
}
