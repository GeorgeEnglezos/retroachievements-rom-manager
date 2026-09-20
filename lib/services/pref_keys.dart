/// Central registry of SharedPreferences keys used by screens/widgets, and of
/// any key read from more than one file. A mistyped key silently returns null
/// instead of erroring, so cross-file keys must live here exactly once.
/// Keys used by a single service stay private constants in that service.
abstract final class PrefKeys {
  // RA credentials + avatar (read by settings, home, game detail).
  static const raUsername = 'ra_username';
  // Legacy plaintext location of the API key. The key now lives in
  // SecretStore (see credentials.dart, which migrates it on first read) and
  // this pref is never written again. SecretStore also reuses this string as
  // its own key name, including on the SharedPreferences fallback path.
  static const raApiKey = 'ra_api_key';
  static const raAvatarVersion = 'ra_avatar_version';
  // RA's canonical UserPic path (/UserPic/Name.png). The media host is
  // case-sensitive, so we persist the authoritative path rather than rebuild it
  // from the (possibly wrong-case) typed username.
  static const raAvatarPath = 'ra_avatar_path';

  // Library root folder (owned by library_folder.dart, also read by settings).
  static const lastFolder = 'last_folder';

  // Cleaning vs play surface (owned by app_mode.dart).
  static const appMode = 'app_mode';

  // What clicking a ROM does: details dialog or launch (owned by rom_tap.dart).
  static const romTapAction = 'rom_tap_action';

  // Set once the first-run wizard completes or is skipped. Unset = show it.
  static const setupDone = 'setup_done';

  // Release version the user dismissed in the update banner (owned by
  // update_check.dart). The banner stays hidden until something newer ships.
  static const skippedRelease = 'skipped_release';

  // Screen-level view preferences.
  static const homeSort = 'home_sort';
  static const homeCombineSystems = 'home_combine_systems';
  static const folderSort = 'folder_sort';
  static const folderSortAsc = 'folder_sort_asc';
  static const folderGridView = 'folder_grid_view';
  // Grid tile size (max cross-axis extent, px) for the folder game grid.
  static const folderGridSize = 'folder_grid_size';
  // Play-mode listing settings, one JSON blob (see play_view.dart).
  static const playView = 'play_view';

  // Games dismissed from Home's mastery/beat spotlight banners (owned by
  // ignored_candidates.dart), a list of member keys.
  static const homeIgnoredSpotlights = 'home_ignored_spotlights';

  // Games the elimination game has judged (owned by cull_store.dart).
  static const cullDecided = 'cull_decided';

  // Named collections of games (owned by playlist_store.dart).
  static const playlists = 'playlists';

  // Systems pinned to the top of the Library grid (owned by
  // favorite_systems.dart).
  static const favoriteSystems = 'favorite_systems';
}
