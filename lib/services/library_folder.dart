import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pref_keys.dart';

/// The selected ROM library root. Screens listen so a pick applies instantly
/// (IndexedStack keeps them alive). Picking lives in pick_library_folder.dart.
final ValueNotifier<String?> libraryFolderListenable = ValueNotifier(null);

/// Reads the saved library folder into [libraryFolderListenable]. Call once at
/// startup before runApp so the first build uses the saved value.
Future<void> initLibraryFolder() async {
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getString(PrefKeys.lastFolder);
  if (last != null && Directory(last).existsSync()) {
    libraryFolderListenable.value = last;
  }
}
