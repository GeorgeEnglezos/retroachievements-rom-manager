import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rom_result.dart' show gameDisplayName;
import 'app_mode.dart';
import 'rom_name.dart';
import 'pref_keys.dart';

/// Whether folder listings are pinned to one layout in play mode, or keep
/// following the toolbar's list/grid toggle.
enum PlayLayout { follow, list, grid }

/// What a ROM listing shows while play mode is on.
///
/// Cleaning is a working state where every piece of information matters, so
/// nothing reads these fields directly: [playView] hands cleaning [all], and
/// only play mode sees the user's choices. File-level detail (file name line,
/// size, status/error text) is cleaning-only and gated on [gamingMode].
@immutable
class PlayView {
  /// The "N ACH" badge, the earned/total read and the progress bar.
  final bool achievementCount;

  /// The "🔥 HOT" badge.
  final bool hot;

  /// The "NO ACH" badge.
  final bool noAchievements;

  /// Filename-derived tag chips (region, HACK, ENG…).
  final bool fileTags;

  final PlayLayout layout;

  /// Defaults are a clean shelf: art, names and achievement counts, none of the
  /// file-level detail you only need while cleaning.
  const PlayView({
    this.achievementCount = true,
    this.hot = true,
    this.noAchievements = false,
    this.fileTags = false,
    this.layout = PlayLayout.follow,
  });

  /// Every element shown: what cleaning mode renders. Spelled out in full so a
  /// later change to a play default can't quietly strip cleaning too.
  static const all = PlayView(
    achievementCount: true,
    hot: true,
    noAchievements: true,
    fileTags: true,
    layout: PlayLayout.follow,
  );

  PlayView copyWith({
    bool? achievementCount,
    bool? hot,
    bool? noAchievements,
    bool? fileTags,
    PlayLayout? layout,
  }) =>
      PlayView(
        achievementCount: achievementCount ?? this.achievementCount,
        hot: hot ?? this.hot,
        noAchievements: noAchievements ?? this.noAchievements,
        fileTags: fileTags ?? this.fileTags,
        layout: layout ?? this.layout,
      );

  Map<String, dynamic> toJson() => {
        'achievementCount': achievementCount,
        'hot': hot,
        'noAchievements': noAchievements,
        'fileTags': fileTags,
        'layout': layout.name,
      };

  /// Missing keys fall back to the constructor defaults, so a setting added
  /// after the user last saved reads as its default instead of as off.
  factory PlayView.fromJson(Map<String, dynamic> j) {
    const d = PlayView();
    return PlayView(
      achievementCount: j['achievementCount'] as bool? ?? d.achievementCount,
      hot: j['hot'] as bool? ?? d.hot,
      noAchievements: j['noAchievements'] as bool? ?? d.noAchievements,
      fileTags: j['fileTags'] as bool? ?? d.fileTags,
      layout: PlayLayout.values.asNameMap()[j['layout']] ?? d.layout,
    );
  }
}

/// The saved play-mode listing settings, shared across screens. Settings writes
/// it; [AppShell] rebuilds from it, which re-runs every mounted screen's build.
final ValueNotifier<PlayView> playViewListenable =
    ValueNotifier(const PlayView());

/// The listing rules in force right now: the saved play settings while play
/// mode is on, everything visible while cleaning.
PlayView get playView => gamingMode ? playViewListenable.value : PlayView.all;

/// Reads the saved settings into [playViewListenable]. Call once at startup.
Future<void> initPlayView() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(PrefKeys.playView);
  if (raw == null) return;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    playViewListenable.value = PlayView.fromJson(decoded);
  } catch (_) {
    // Truncated, hand-edited, or written by a version that typed a field
    // differently. Startup runs before runApp, so anything thrown here would
    // take the whole app down; the defaults are always a valid fallback.
  }
}

/// Persists the settings and publishes them to listeners.
Future<void> savePlayView(PlayView view) async {
  playViewListenable.value = view;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(PrefKeys.playView, jsonEncode(view.toJson()));
}

/// Title for a listing row: the RetroAchievements game name, falling back to
/// the file name. In play mode that fallback drops the extension and
/// `(...)`/`[...]` tags; cleaning keeps the raw name.
String listingTitle(String? raTitle, String fileName) {
  if (!gamingMode) return gameDisplayName(raTitle, fileName);
  final clean = cleanRomName(fileName);
  return gameDisplayName(raTitle, clean.isEmpty ? fileName : clean);
}
