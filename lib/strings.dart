// Every piece of text the app shows, in one place, grouped by tab and feature.
// Widgets reference these instead of writing string literals;
// test/tool/list_ui_strings_test.dart fails if a new literal slips into
// lib/screens or lib/widgets.

/// Shared formatting: separators and value shapes used across tabs.
abstract final class CommonStrings {
  static const dotSep = ' · ';
  static const dotSepWide = '  ·  ';
  static const dotSepWider = '   ·   ';
  static const listSep = ', ';
  static const pathSep = ' / ';
  static const noValue = '-';
  static const loading = '…';
  static String fraction(Object done, Object total) => '$done/$total';
  static String percent(num value) => '${value.round()}%';
  static String version(String version) => 'v$version';
}

/// App shell: nav, update banner, gamepad hints, scan progress bar.
abstract final class ShellStrings {
  // -- Nav
  static const navHome = 'HOME';
  static const navLibrary = 'LIBRARY';
  static const navPlayNext = 'PLAY NEXT';
  static const navCull = 'CULL';
  static const navStorage = 'STORAGE';
  static const navLogs = 'LOGS';
  static const navSettings = 'SETTINGS';
  static String shortcutLaunchFailed(String err) =>
      "Couldn't launch shortcut: $err";
  static const appName = 'RARM';
  static const author = 'by George Englezos';

  // -- Update banner
  static String browserOpenFailed(String url) =>
      "Couldn't open your browser. The link is on your "
      'clipboard: $url';
  static const updateAvailable = 'UPDATE AVAILABLE';
  static const getUpdateButton = 'GET IT';
  static const hideUpdateTooltip = 'Hide until the next release';

  // -- Gamepad hints
  static const navigateGlyph = '↕↔';
  static const navigateHint = 'Navigate';
  static const selectGlyph = 'A';
  static const selectHint = 'Select';
  static const backGlyph = 'B';
  static const backHint = 'Back';

  // -- Scan progress bar
  static const cancelling = 'Cancelling…';
  static const cancel = 'Cancel';
}

/// Setup wizard, restore backup, pick library folder.
abstract final class WizardStrings {
  // -- Wizard frame
  static const skipSetup = 'Skip setup';
  static const backButton = 'BACK';
  static const continueButton = 'CONTINUE';
  static const laterButton = 'LATER';
  static const startScanButton = 'START SCAN';
  static const stepWelcome = 'WELCOME';
  static const stepAccount = 'ACCOUNT';
  static const stepStyle = 'STYLE';
  static const scan = 'SCAN';
  static String stepSemantics(int step, int total, String name) =>
      'Step $step of $total, $name';

  // -- Welcome step
  static const welcomeTitle = 'Welcome to Retroachievements Rom Manager';
  static const welcomeBody =
      'This app helps you clean up your ROM library and acts as an emulation frontend. '
      'It scans your game folder, works out which game each file is, and matches it '
      'against RetroAchievements.';
  static const welcomeSetupCovers =
      'Setup covers your RetroAchievements account, your ROM folder, '
      'how the app looks, and a first scan.';
  static const welcomeRestoreHint =
      'Moving from another PC? Restore a backup instead.';
  static const restoreFromBackupButton = 'RESTORE FROM BACKUP';

  // -- Style step
  static const styleTitle = 'Make it yours';
  static const styleBody = 'All of this can be changed later in Settings.';
  static const modeLabel = 'MODE';
  static const themeLabel = 'THEME';
  static const uiScaleLabel = 'UI SCALE';

  // -- Credentials step
  static const credentialsMissing =
      'Enter both your username and your Web API key.';
  static const credentialsRejected =
      "We couldn't sign in with that username and key. "
      'Check both and try again.';
  static const accountTitle = 'Your RetroAchievements account';
  static const accountBody =
      'The app reads your achievement progress with a free Web API key. '
      'Open your RetroAchievements settings while signed in and copy the '
      'key from the Applications tab.';
  static const getApiKeyButton = 'GET MY API KEY';
  static const usernameLabel = 'Username';
  static const apiKeyLabel = 'Web API key';
  static const checkingButton = 'CHECKING…';
  static const verifyButton = 'VERIFY';
  static String signedInAs(String username) => 'Signed in as $username.';

  // -- Folder step
  static const scrapedLooking = 'Looking for Skraper media and details…';
  static String scrapedFound(int games, int systems) =>
      'Found Skraper media and details for $games '
      'game${games == 1 ? '' : 's'} across $systems '
      'system${systems == 1 ? '' : 's'}.';
  static const scrapedExplainer =
      'This app primarily uses RetroAchievements for images and game '
      'details. It also recognises media and metadata from Skraper, '
      "and will show those alongside RA's.";
  static const autoDetect = 'Auto-detect';
  static const folderTitle = 'Your ROM folder';
  static const folderBody =
      'Pick the parent folder that holds all your consoles. Each '
      'subfolder is hashed as the console shown next to it. Correct any '
      'the app guessed wrong, and hide any you do not want scanned. '
      'Folders with zero roms are hidden in the app by default';
  static const pickFolderButton = 'PICK FOLDER';
  static const changeFolderButton = 'CHANGE FOLDER';
  static const noFolderPicked = 'No folder picked yet.';
  static const noSubfolders = 'No subfolders found in that folder.';
  static const folderColumn = 'FOLDER';
  static const excludedFolder = 'Excluded, not scanned';
  static const counting = 'counting…';
  static String romCount(int count) => '$count ROM${count == 1 ? '' : 's'}';

  // -- First scan step
  static const readyTitle = 'Ready to scan';
  static const readyBody =
      'The scan reads every ROM to work out which game it is, then asks '
      'RetroAchievements what it knows about that game and how far you '
      'have got with it.';
  static const readyDuration =
      'On a large library this takes a while. You can stop it at any '
      'point. Systems that already finished are skipped next time.';

  // -- Restore backup
  static const restoreConfirmTitle = 'Restore from backup?';
  static const restoreConfirmBody =
      'This replaces everything you have now: scan results, imported '
      'metadata, cached artwork and settings. Your RetroAchievements API '
      'key is not in a backup, so the one you have now is kept. Restart '
      'the app afterwards.';
  static const restoreButton = 'Restore';
  static const chooseBackupZip = 'Choose a backup zip';
  static const restoredTitle = 'Restored';
  static const restoredBody =
      'Close and reopen the app to load the backup. Using '
      'it before then can overwrite what was just restored.';
  static const notABackup = 'That zip is not a RARM backup.';
  static const restoreFailed = 'Restore failed, see the log for details.';

  // -- Pick library folder
  static const grantFilesAccess =
      'Grant "All files access", then tap Pick folder again.';
  static const selectRomFolder = 'Select ROM folder';
}

/// Home: dashboard, big picture, unlock history, dashboard stats.
abstract final class HomeStrings {
  // -- Dashboard
  static String wontSuggest(String title) =>
      'Won\'t suggest "$title" here again';
  static const undo = 'Undo';
  static const emptyTitle = 'Your dashboard fills up as you play';
  static const emptyBody =
      'Pick your ROM folder and run a scan on the Library tab. Games you '
      'have progress on show up here, closest to mastery first.';
  static const goToLibrary = 'Go to Library';

  // -- Couch home
  static const libraryEmpty = 'Your library fills up as you play.';
  static const rowJumpBackIn = 'Jump back in';
  static const rowClosestToMastery = 'Closest to mastery';
  static const rowPopularUnplayed = 'Popular & unplayed';
  static const mastery = 'MASTERY';
  static const closestToBeat = 'CLOSEST TO BEAT';

  // -- Couch hero
  static const continuePlaying = 'CONTINUE PLAYING';
  static const notInterested = 'Not interested, show next';
  static String achievementProgress(int earned, int total) =>
      '$earned/$total achievements';
  static String players(String count) => '$count players';

  // -- Console browser
  static const nothingHere = 'Nothing here yet.';
  static const allConsoles = 'All Consoles';
  static String gameCount(int count) =>
      '$count '
      '${count == 1 ? 'game' : 'games'}';
  static const pickSystemPrompt = 'Pick a system to see its top games';

  // -- Unlock history
  static const unlocksLoadFailed = "Couldn't load unlocks.";
  static const noUnlocks =
      'No recent unlocks yet. Earn achievements and they show up '
      'here.';
  static const recentUnlocks = 'RECENT UNLOCKS';

  // -- Dashboard stats
  static const statGames = 'Games';
  static const statMastered = 'Mastered';
  static const statAchievements = 'Achievements earned';
  static const statLibrarySize = 'Library size';
  static const statSystems = 'Systems';
}

/// Play Next tab.
abstract final class PlayNextStrings {
  static const emptyMessage =
      'No supported games with achievement data yet. '
      'Fetch some systems first.';
}

/// Library tab: systems list, folder cards, search.
abstract final class LibraryStrings {
  // -- Toolbar
  static const scanHealthTooltip = 'Scan health & export';
  static const allGames = 'All games';
  static const sortFoldersTooltip = 'Sort folders';
  static const pickFolderButton = 'Pick folder';

  // -- Sections
  static const shortcutsSection = 'Shortcuts';
  static const favoritesSection = 'Favorites';
  static const systems = 'Systems';
  static const noRetroAchievements = 'No RetroAchievements';

  // -- Grid
  static const pickFolderPrompt = 'Pick a folder to browse subfolders.';
  static String folderCount(int count) => '$count folders';
  static String gameCount(int count) => '$count games';

  // -- Folder card
  static const notScannedYet = 'Not scanned yet';
  static const withAchievements = 'With achievements';

  // -- System menu
  static const removeFromFavorites = 'Remove from favorites';
  static const favorite = 'Favorite';
  static String ignoreFolder(String name) => 'Ignore "$name"';
  static String ignoringFolder(String name) =>
      'Ignoring "$name". Manage the list in Settings.';
  static const undo = 'Undo';

  // -- Playlist menu
  static const rename = 'Rename';
  static const delete = 'Delete';
  static const renamePlaylistTitle = 'Rename playlist';
  static const cancelButton = 'Cancel';
  static const saveButton = 'Save';

  // -- Refresh
  static String newFilesFound(int n) =>
      '$n new file${n == 1 ? '' : 's'} found since the last scan.';
  static const fetchAction = 'Fetch';
  static const folderMissing = 'Folder no longer exists. Pick a new one.';
  static String refreshedFolders(int added, int removed) =>
      'folders +$added / −$removed';
  static String refreshedFiles(int added, int removed) =>
      'files +$added / −$removed';
  static String refreshed(List<String> parts) =>
      'Refreshed: ${parts.join('  ·  ')}';

  // -- Remove missing systems
  static const noMissingSystems = 'No missing systems to remove.';
  static String removeMissingTitle(int count) =>
      'Remove $count missing system${count == 1 ? '' : 's'}?';
  static String removeMissingBody(List<String> missing) =>
      'These folders are not on disk right now:\n\n'
      '${missing.join('\n')}\n\n'
      'Their scan results will be deleted. If one of these is on a drive '
      'that is currently unplugged, cancel and plug it back in first.';
  static const removeButton = 'Remove';
  static String removedMissing(int count) =>
      'Removed $count missing system${count == 1 ? '' : 's'}.';

  // -- Scan all
  static const noSubfolders = 'No subfolders to scan.';
  static const raListsRefreshed = 'RA lists refreshed';
  static const noFoldersMatchScope = 'No folders match that scope.';
  static String scanAllProgress(
    int index,
    int count,
    String folder,
    int checked,
    int total,
  ) =>
      'System $index/$count: $folder  •  '
      '${total == 0 ? '$checked' : '$checked/$total'}';
  static String skippedEntry(String folder, String reason) =>
      '$folder ($reason)';
  static String skippedSystems(List<String> skipped) =>
      'Skipped ${skipped.length} '
      'system${skipped.length == 1 ? '' : 's'}: '
      '${skipped.take(3).join(', ')}'
      '${skipped.length > 3 ? '…' : ''}';
  static String setUpdates(int n, String sample) =>
      '$n game${n == 1 ? '' : 's'} gained new achievements on RA: '
      '$sample${n > 3 ? '…' : ''}';

  // -- Scraped import
  static const scrapedDataTitle = 'Scraped data found';
  static String scrapedDataBody(int found) =>
      'Found gamelist.xml (skraper) for $found '
      'folder(s). Import artwork & details to fill gaps?';
  static const skipButton = 'Skip';
  static const importButton = 'Import';

  // -- Search
  static const searchHint = 'Search games…';
  static const excludeHint = 'Exclude results containing… (Enter to add)';
  static const flatListTooltip = 'Flat list';
  static const groupedListTooltip = 'Grouped list';
  static const refreshResultsTooltip = 'Refresh results';
  static String nothingFound(String query) => 'Nothing found for "$query"';
  static String searchGroupLabel(String name, int count) =>
      '$name · $count ${count == 1 ? "result" : "results"}';
  static String searchSystemSubtitle(String name, int count) =>
      '$name · $count ${count == 1 ? 'game' : 'games'}';
  static String excludedFiles(int count) =>
      'Excluded $count file${count == 1 ? '' : 's'}';
  static const progressSynced = 'Progress synced';
  static String syncProgressFailed(Object e) => 'Failed to sync progress: $e';
}

/// Fetch FAB, fetch tasks dialog, Android disc hashing dialog.
abstract final class FetchStrings {
  // -- Fetch FAB
  static const fabTooltip = 'Update library (rescan & sync progress)';

  // -- Fetch tasks dialog
  static const dialogTitle = 'Update library';
  static const globalDescription =
      'Re-reads your folders for added and removed files, '
      'hashes anything new, matches it on '
      'RetroAchievements and syncs your progress.';
  static const folderDescription =
      'Re-reads this folder for added and removed files, '
      'hashes anything new, matches it on '
      'RetroAchievements and syncs your progress.';
  static const advanced = 'Advanced';
  static const foldersLabel = 'Folders';
  static const scopeChanged = 'Only changed folders';
  static const scopeUnfetched = 'Only unfetched folders';
  static const scopeAll = 'All folders';
  static const removeMissingTitle = 'Remove missing systems';
  static const removeMissingSubtitle =
      'Deletes scan results for folders that are no '
      'longer on disk.';
  static const reHashTitle = 'Re-hash every ROM';
  static const reHashSubtitle =
      'Slow: reads every file again, including ones '
      'already identified.';
  static const refreshListsTitle = 'Force refresh RA game lists';
  static String refreshListsSubtitle(int days) =>
      'Normally re-pulled on their own every '
      '$days days.';
  static const updateButton = 'Update';

  // -- Android disc hashing dialog
  static const androidDiscTitle = 'GameCube & Wii on Android';
  static const androidDiscBody =
      "Compressed .rvz and .wia dumps can't be hashed on Android yet, so they "
      "can't be matched to RetroAchievements. On-device hashing for these "
      'formats is under development.\n\n'
      'For now, convert them to .iso (or .ciso/.wbfs/.gcz, which do hash on '
      'Android), or hash them on the desktop version.';
  static const okButton = 'OK';
}

/// Scan health screen.
abstract final class ScanHealthStrings {
  static String reportFileName(String ext) => 'library-report.$ext';
  static String systemReportBase(String system) => '$system-library';
  // -- Stats
  static const title = 'Scan health';
  static const totalRoms = 'Total ROMs';
  static const supported = 'Supported';
  static const unsupported = 'Unsupported';
  static const notFetched = 'Not fetched';
  static const withProgress = 'With progress';
  static String summary(String size, int supportedPercent) =>
      'Total size: $size'
      '   ·   Supported $supportedPercent% '
      'of looked-up games';

  // -- Export report
  static const exportReport = 'Export report';
  static const csv = 'CSV';
  static const json = 'JSON';
  static const markdown = 'Markdown';
  static const exportDialogTitle = 'Export library report';
  static String savedTo(String path) => 'Saved to $path';
  static const exportFailed = 'Export failed';

  // -- Export one system
  static const exportOneSystem = 'Export one system';
  static const exportOneSystemHint =
      'A game list for a single system, with the fields and order you pick.';
  static const exportSystemButton = 'Export system…';
  static const exportSystemTitle = 'Export system';
  static const systemLabel = 'System';
  static const fieldsLabel = 'Fields';
  static const hasAchievements = 'Has achievements';
  static const progress = 'Progress';
  static const size = 'Size';
  static const howMany = 'How many';
  static const all = 'All';
  static const pdf = 'PDF';
}

/// Folder view: toolbar, ROM list/grid/rows, bulk bar, covers.
abstract final class FolderStrings {
  // -- Fetch and sync
  static const unknownConsoleMapping =
      'Unknown console for this folder. Set it in Settings → System mapping.';
  static const thisSystem = 'This system';
  static String notOnRetroAchievements(String name) =>
      "$name isn't on RetroAchievements. Add a metadata source in "
      'Settings to fetch game info.';
  static String unsupportedByMetadataSource(String name) =>
      "$name isn't supported by the selected metadata source.";
  static const noMatchedGamesToSync = 'No matched games to sync.';
  static String syncProgressFailed(Object error) =>
      'Failed to sync progress: $error';
  static String notSupportedByRetroAchievements(String name) =>
      '$name is not supported by RetroAchievements.';
  static const unknownConsole = 'Unknown console for this folder.';

  // -- Exclude
  static String excludedFiles(int n) =>
      'Excluded $n file${n == 1 ? '' : 's'}. Manage in Settings.';
  static const undo = 'Undo';

  // -- Duplicates
  static String copies(int count) => '⧉ $count COPIES';

  // -- Toolbar
  static const hideSearchAndFilters = 'Hide search & filters';
  static const showSearchAndFilters = 'Show search & filters';
  static const searchHint = 'Search name or title';
  static const sortLabel = 'SORT';
  static const duplicatesToggle = 'Duplicates';
  static const hotToggle = 'Hot';
  static const filtersButton = 'Filters';
  static const backTooltip = 'Back';

  // -- ROM tiles and rows
  static String consoleAfterCount(String console) => '  ·  $console';
  static const nkitUnsupported = 'NKit format not supported';
  static const compressedDiscNeedsDolphin =
      'Compressed disc. Add Dolphin in Settings → Emulators to hash it';
  static String progressPercent(double frac) => '${(frac * 100).round()}%';

  // -- Bulk action bar
  static String deletingProgress(int done, int total) =>
      'Deleting $done of $total…';
  static String selectedCount(int count) => '$count selected';
  static const favoritesAction = 'Favorites';
  static const playlistAction = 'Playlist';
  static const deleteAction = 'Delete';
  static const excludeAction = 'Exclude';
  static const clearSelection = 'Clear selection';
}

/// Filter panel, active filter chips, progress labels.
abstract final class FilterStrings {
  // -- Filter panel
  static const statusSection = 'Status';
  static const noAchievements = 'No achievements';
  static const progressSection = 'Progress';
  static const genreSection = 'Genre';
  static const tagsSection = 'Tags';
  static const playlistsSection = 'Playlists';
  static String playlistShowAll(String name) => '$name: show all';
  static String playlistOnly(String name) => '$name: only';
  static String playlistExclude(String name) => '$name: exclude';

  // -- Progress states
  static const notStarted = 'Not started';
  static const started = 'Started';
  static const nearComplete = 'Near complete';
  static const mastered = 'Mastered';
}

/// Playlist view, toolbar, picker.
abstract final class PlaylistStrings {
  // -- Playlist view
  static const unknownSystem = 'Unknown';
  static const noGamesMatch = 'No games match.';

  // -- Toolbar
  static const listLayout = 'List';
  static const bySystemLayout = 'By system';

  // -- New playlist dialog
  static const newPlaylistTitle = 'New playlist';
  static const playlistNameHint = 'Playlist name';
  static const cancel = 'Cancel';
  static const create = 'Create';

  // -- Picker
  static const addToPlaylistTitle = 'Add to playlist';
  static const autoManaged = 'Auto-managed';
  static const newPlaylistEllipsis = 'New playlist…';
  static const done = 'Done';
  static String addRomsToPlaylist(int count) =>
      'Add $count ROM${count == 1 ? '' : 's'} to playlist';
  static const noPlaylistsYet = 'No playlists yet.';
}

/// Cull screen, deck, card.
abstract final class CullStrings {
  // -- Cull screen
  static const noScannedSystems =
      'No scanned systems yet. Scan your library first.';
  static String decidedCount(int done, int total) => '$done / $total decided';

  // -- Deck
  static const startOverTitle = 'Start over?';
  static String startOverConfirm(String consoleName) =>
      'Forget all $consoleName decisions and rebuild the deck? '
      'Trashed games stay in the Trash playlist.';
  static const startOver = 'Start over';
  static const browserOpenFailed = "Couldn't open browser";
  static const startOverTooltip = 'Start over for this console';
  static String allGamesDecided(String consoleName) =>
      'All $consoleName games decided.';
  static const everyConsoleDone = 'Every console is done.';
  static String nextConsole(String next) => 'Next: $next';
  static const undoLastCard = 'Undo last card';
  static const undoAction = 'UNDO';
  static const trashAction = 'TRASH';
  static const trashHint =
      'Moved to the Trash playlist. Nothing is deleted; '
      'review and delete from there.';
  static const favoriteAction = 'FAVORITE';
  static const keepAction = 'KEEP';

  // -- Card
  static const searchGoogle = 'Google';
  static const gameDetails = 'Details';
  static const achievementsLabel = 'ACHIEVEMENTS';
  static String points(int points) => '$points pts';
  static String players(String count) => '$count players';
}

/// Storage screen.
abstract final class StorageStrings {
  static const allSystems = 'ALL SYSTEMS';
  static const noScannedSizes = 'NO SCANNED SIZES YET. SCAN A FOLDER FIRST';
  static const back = 'BACK';
}

/// Logs screen.
abstract final class LogsStrings {
  static String sessionTime(String? h, String? m, String? s) => '$h:$m:$s';
  static const title = 'Logs';
  static const clearSessionTooltip = 'Clear current session logs';
  static const copiedToClipboard = 'Copied to clipboard';
  static const copyTooltip = 'Copy log to clipboard';
  static const refreshTooltip = 'Refresh file list';
  static const currentSession = 'Current session';
  static const noSavedLogs = 'No saved logs';
  static const noLogsYet = 'No logs yet.';
  static String entryTime(String ts) => '$ts ';
  static String entryLevel(String level) => '[$level] ';
  static String entrySource(String source) => '$source: ';
  static const emptyLogFile = 'Empty log file.';
}

/// Game detail dialog, progress labels and ROM badges.
abstract final class GameStrings {
  // Achievement type marks.
  static const markStar = '★';
  static const markCrown = '👑';
  static const markWarning = '⚠';
  // -- Achievement types
  static const winCondition = 'Win condition';
  static const progression = 'Progression';
  static const missable = 'Missable';

  // -- Game detail dialog
  static const noCredentials =
      'Add RA credentials in Settings to load achievements';
  static const achievementsLoadFailed = "Couldn't load achievements";
  static const favorited = 'Favorited';
  static const favorite = 'Favorite';
  static const unverifiedMatch = 'Unverified name match';
  static String disc(int number) => 'Disc $number';
  static String fileOfInstalled(int index, int total) =>
      'File $index of $total · installed '
      'content, the base game is what boots';
  static String fileOf(int index, int total) => 'File $index of $total';
  static const achievements = 'Achievements';
  static const points = 'Points';
  static const players = 'Players';
  static const developer = 'Developer';
  static const publisher = 'Publisher';
  static const genre = 'Genre';
  static const released = 'Released';
  static const rating = 'Rating';
  static const setReleased = 'Set released';
  static const setUpdated = 'Set updated';
  static const yourProgress = 'Your progress';
  static String lastPlayed(String date) => 'Last played: $date';
  static const noAchievementsInSet = 'No achievements in this set';
  static String masteryEffort(int effort) =>
      'Effort to master: ~$effort RetroPoints still to earn';
  static String pointsShort(int points) => '$points pts';
  static String typeMarker(String mark, String label) => '$mark $label';
  static String earnedOn(String date) => ' · Earned $date';
  static String playersEarned(String count) => '$count players earned this';
  static String shortDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day} ${dt.year}';
  }

  // -- Progress
  static const completedSet = "You've completed this set (softcore)";
  static const masteredSet = "You've mastered this set";
  static String closeToMastery(int remaining) =>
      'Close to mastery: $remaining '
      'achievement${remaining == 1 ? '' : 's'} to go';
  static String achievementsToGo(int remaining) =>
      '$remaining achievement${remaining == 1 ? '' : 's'} to go';
  static const mastered = 'Mastered';
  static const completed = 'Completed';
  static const beaten = 'Beaten';
  static const notStarted = 'Not started';
  static String progressCount(int earned, int total) => '$earned / $total';

  // -- Badges
  static const dupBadge = '⧉ DUP';
  static const dupTooltip = 'Another copy of this game is in this folder.';
  static const hotBadge = '🔥 HOT';
  static String hotTooltip(int? players) =>
      'Hot on RetroAchievements: '
      '$players players have earned achievements in this set ';
  static const noAchGameTooltip =
      'No achievements on RetroAchievements for this game.';
  static const noAchConsoleTooltip =
      'This console is not on RetroAchievements.';
  static const noAchBadge = 'NO ACH';
  static String achBadge(int count) => '$count ACH';
  static String switchFilesBadge(int count) => 'files: $count';
  static String switchFilesTooltip(int count) =>
      '$count files: base game, updates and DLC. '
      'Only the base game boots.';
  static String discsBadge(int count) => 'disks: $count';
  static String discsTooltip(int count) => '$count-disc game';
}

/// ROM actions menu, play-with, set emulator and delete confirmation.
abstract final class GameActionStrings {
  // -- Actions menu
  static const gameDetails = 'Game details';
  static const play = 'Play (beta)';
  static const playWithMenu = 'Play with…';
  static const desktopShortcut = 'Create desktop shortcut (beta)';
  static const homeScreenShortcut = 'Add to home screen (beta)';
  static const reveal = 'Reveal in Explorer';
  static const copyPath = 'Copy path';
  static const searchGoogle = 'Search Google';
  static const openRaPage = 'Open RA page';
  static const whyUnsupported = 'Why unsupported?';
  static const notDuplicate = 'Not a duplicate';
  static const syncProgress = 'Sync progress';
  static const fetch = 'Fetch';
  static const addToPlaylist = 'Add to playlist…';
  static const delete = 'Delete';
  static const exclude = 'Exclude from scans';

  // -- Action results
  static const revealFailed = "Couldn't reveal file";
  static const pathCopied = 'Path copied';
  static const browserFailed = "Couldn't open browser";
  static String excluded(String fileName) => 'Excluded "$fileName"';
  static const launchFailed = "Couldn't launch ROM";
  static String openInFailed(String emulator, String error) =>
      "Couldn't open in $emulator: $error";
  static const unknownConsole =
      'Unknown console for this ROM. Set its folder system in Settings.';
  static const thisSystem = 'this system';
  static String noLaunchCommand(String emulator) =>
      '$emulator has no launch command for this system.';
  static const homeShortcutAdded = 'Shortcut added to your home screen.';
  static String shortcutFailed(String error) =>
      "Couldn't create shortcut: $error";
  static const desktopShortcutsWindowsOnly =
      'Desktop shortcuts are only available on Windows.';
  static const launchCommandFailed = "Couldn't build the launch command.";
  static const desktopShortcutFailed = "Couldn't create the shortcut.";
  static const desktopShortcutCreated = 'Shortcut created on your Desktop.';
  static const deleteFailed = "Couldn't delete file";

  // -- Why unsupported dialog
  static const whyUnsupportedBody =
      "RetroAchievements didn't recognise this file's hash. Common causes:\n\n"
      "• Wrong region or revision (e.g. an EU ROM where RA expects USA).\n"
      "• A bad dump or hacked/translated ROM; RA needs a known-good redump.\n"
      "• The game has no achievement set yet.\n"
      "• A patch (IPS/BPS) needs applying first.\n\n"
      "Open this console's supported list on RetroAchievements to compare "
      "the exact titles and hashes RA accepts.";
  static const close = 'Close';
  static const openSupportedList = 'Open RA supported list';

  // -- Play with dialog
  static const playWithTitle = 'Play with';
  static String emulatorsFor(String console) =>
      'Emulators you added for $console:';
  static const cancel = 'Cancel';

  // -- Set emulator dialog
  static String setEmulatorTitle(String console) => 'Set emulator for $console';
  static const noEmulatorsAndroid =
      'No emulators added yet. Pick an installed app below. '
      'This system will use it for every game in the folder.';
  static const noEmulatorsDesktop =
      'No emulators added yet. Browse for one below. This '
      'system will use it for every game in the folder.';
  static const pickEmulator = 'Pick one of your emulators:';
  static const pickApp = 'Pick app…';
  static const browseExe = 'Browse exe…';

  // -- Delete confirmation
  static const deleted = 'Deleted';
  static const movedToRecycleBin = 'Moved to Recycle Bin';
  static const permanentlyDeleteVerb = 'Permanently delete';
  static const moveVerb = 'Move';
  static const toRecycleBin = ' to the Recycle Bin';
  static String deleteFiles(String verb, int files, String suffix) =>
      '$verb $files file${files == 1 ? '' : 's'}$suffix?';
  static String deleteDiscs(
    String verb,
    int discs,
    String? name,
    String suffix,
  ) => "$verb all $discs discs of '$name'$suffix?";
  static String deleteOne(String verb, String? name, String suffix) =>
      "$verb '$name'$suffix?";
  static const deletePermanentlyTitle = 'Delete permanently?';
  static const moveToRecycleBinTitle = 'Move to Recycle Bin?';
}

/// Settings tab.
abstract final class SettingsStrings {
  static String backupFileName(DateTime day) =>
      'rarm-backup-${day.toIso8601String().split('T').first}.zip';
  // -- Screen
  static const title = 'Settings';
  static const generalTab = 'General';
  static const systems = 'Systems';

  // -- Account
  static const accountTitle = 'Account';
  static const accountHelp =
      'Web API key from retroachievements.org → Settings → Applications → Web API Key.';
  static const usernameLabel = 'Username';
  static const apiKeyLabel = 'Web API key';

  // -- Library folder
  static const libraryFolderTitle = 'Library folder';
  static const libraryFolderHelp =
      'The parent folder holding your per-system ROM subfolders.';
  static const pickFolderButton = 'Pick folder';
  static const changeFolderButton = 'Change folder';

  // -- Scan filters
  static const scanFiltersTitle = 'Scan filters';
  static const scanFiltersHelp =
      'Comma-separated. Unlisted extensions are skipped; ignored folders '
      'are hidden and never scanned.';
  static const extensionsLabel = 'Extensions';
  static const extensionsHint = 'chd, nds, gb, gba, ...';
  static const resetExtensionsTooltip =
      'Replaces the list above with the extensions the app '
      'ships with, discarding your edits.';
  static const resetExtensionsButton = 'Reset to defaults';
  static const ignoredFoldersLabel = 'Ignored folders';
  static const ignoredFoldersHint = 'BIOS, Saves, Cheats';
  static const excludedFilesLabel = 'Excluded files';
  static const excludedFilesHint = r'C:\roms\snes\bad-dump.sfc';
  static const excludedFilesHelp =
      'Full paths, one per line. Excluded files are hidden and '
      'skipped, but not deleted.';

  // -- Display
  static const displayTitle = 'Display';
  static const displayHelp =
      'Show the full system name ("Super Nintendo") or the original '
      'folder name ("SNES") on cards and titles.';
  static const fullSystemNamesSwitch = 'Show full system names';
  static const combineSystemsSwitch = 'Combine systems';
  static const combineSystemsHelp =
      'Merge folders that map to the same console into one card '
      'on Library.';
  static const uiScaleTitle = 'UI scale';
  static const uiScaleHelp =
      'Zoom the whole app in or out. Applies immediately.';

  // -- Mode
  static const modeTitle = 'Mode';

  // -- Clicking a game
  static const romTapTitle = 'Clicking a game';
  static const romTapHelp =
      'What a plain click on a game does. Ctrl/shift-click still '
      'multi-selects. Right click on a game to see the other option.';
  static const romTapDetail = 'Open details';
  static const romTapPlay = 'Play';

  // -- Kiosk listings
  static const kioskListingsTitle = 'Kiosk listings';
  static const kioskListingsHelp =
      'What ROM lists show in Kiosk mode. Cleaning always shows '
      'everything.';
  static const achievementCountSwitch = 'Achievement count';
  static const achievementCountHelp =
      'The ACH badge, earned/total and the progress bar.';
  static const hotBadgeSwitch = 'Hot badge';
  static const noAchievementsBadgeSwitch = 'No-achievements badge';
  static const fileTagsSwitch = 'File name tags';
  static const fileTagsHelp =
      'Region, HACK, ENG and friends, read off the file name.';
  static const layoutLabel = 'Layout';
  static const layoutFollow = 'Both enabled';
  static const layoutList = 'List';
  static const layoutGrid = 'Grid';

  // -- Theme
  static const themeTitle = 'Theme';
  static const themeHelp = 'Pick a colour palette. Applies immediately.';

  // -- Data
  static const dataTitle = 'Data';
  static const dataHelp =
      'Back up or restore everything the app has saved. Delete it to '
      'start over from a fresh scan.';
  static const backupTooltip =
      'Writes a zip holding your scan results, imported '
      'metadata, cached artwork, playlists and settings. ROM '
      'files and your API key are not included.';
  static const backupButton = 'Create Data Backup';
  static const restoreTooltip =
      'Loads a backup zip, replacing everything you have '
      'now except your API key. Needs an app restart afterwards.';
  static const restoreButton = 'Restore Data Backup';
  static const deleteDataTooltip =
      'Choose what to delete: scan results, playlists, '
      'imported metadata, cached artwork. Your ROM files, '
      'settings and login are never touched.';
  static const deleteDataButton = 'Delete Data';
  static const backupDialogTitle = 'Back up library';
  static const backupStarted =
      'Backing up, this can take a while on a large library.';
  static String backupSaved(String path) => 'Backup saved to $path';
  static const backupFailed = 'Backup failed, see the log for details.';
  static String dataDeleted(int deleted, int total) =>
      'Deleted $deleted of '
      '$total kinds of data.';
  static const deleteDataFailed =
      'Could not delete everything, see the log for details.';

  // -- Setup
  static const setupTitle = 'Wizard';
  static const setupHelp =
      'Opens the first-run wizard again (RetroAchievements account, '
      'library folder, mode, theme).';
  static const setupWizardButton = 'Setup Wizard';

  // -- About
  static const aboutTitle = 'About';
  static const aboutHelp = 'Retroachievements Rom Manager by George Englezos.';
  static String version(String version, String build) => 'v$version+$build';

  // -- Emulators
  static const emulatorsTitle = 'Emulators';
  static const emulatorsHelpAndroid =
      'The emulator apps you have. Each system below picks one '
      'of them; Play then sends the ROM straight to that app.';
  static const emulatorsHelpDesktop =
      'The emulators you have. Each system below picks one of '
      'them. Adding RetroArch auto-fills the right core for '
      'most systems; standalone emulators (Dolphin, PCSX2, '
      'DuckStation, PPSSPP) connect their own.';
  static const launchFullscreen = 'Launch games in fullscreen';
  static const noEmulators = 'None yet, add one below.';
  static const changeAppTooltip = 'Change app';
  static const changeExeTooltip = 'Change exe';
  static const removeTooltip = 'Remove';
  static const extraArgsLabel =
      'Extra arguments (applied to all this '
      "emulator's systems)";
  static const addEmulatorApp = 'Add emulator (pick app)';
  static const addEmulatorExe = 'Add emulator (browse exe)';
  static const scanning = 'Scanning…';
  static const detectEmulatorApps = 'Detect installed emulators';
  static const scanEmulatorFolder = 'Scan a folder for emulators';
  static String emulatorAdded(String name) =>
      'Added $name. Connected its default systems below.';
  static const noNewEmulatorApps = 'No new emulator apps found.';
  static const noNewEmulatorsInFolder =
      'No new emulators found in that folder.';
  static String emulatorsAdded(Iterable<String> names) =>
      'Added ${names.join(', ')}. '
      'Connected their default systems below.';
  static String emulatorExeDialogFor(String name) =>
      'Choose the emulator executable for $name';
  static String emulatorUpdated(String name) => 'Updated $name.';

  // -- Emulator pickers
  static const emulatorExeDialog = 'Choose the emulator executable';
  static const filePickerFailed = "Couldn't open file picker";
  static const emulatorFolderDialog =
      'Select the folder your emulators live in';
  static const folderPickerFailed = "Couldn't open folder picker";
  static const appPickerTitle = 'Pick an emulator app';
  static const noApps = 'No apps found.';
  static const cancel = 'Cancel';

  // -- Systems
  static const systemsHelp =
      'The systems in your library, the same ones Library shows. The '
      'console decides how a ROM is hashed and matched, so a wrong '
      'guess means no achievements; disc systems (PS1, PSP, Saturn, …) '
      'must be set, then re-scan.';
  static const noSystems =
      'No scanned systems yet. Pick a library folder under General and '
      'scan it from Home, then come back to map its consoles.';
  static const noRetroAchievements = 'No RetroAchievements';
  static String systemStats(int games, String size) => '$games games · $size';
  static const consoleLabel = 'Console';
  static String consoleAuto(String detected) => 'Auto ($detected)';
  static String consoleAutoDetect(String detected) => 'Auto-detect ($detected)';
  static const consoleNotRecognised = 'not recognised';
  static String consoleId(int id) => 'id $id';
  static const pickConsoleFirst =
      'Pick a console above before connecting an emulator.';
  static const emulatorLabel = 'Emulator';
  static const noEmulatorsAdded = 'None added yet. See the Emulators tab.';
  static const emulatorNotSet = 'Not set';
  static const sharedConsole = 'Shared with the other folders on this console.';
  static const argumentsLabel = 'Arguments ({file.path} is the ROM)';

  // -- Clear data
  static const clearDataTitle = 'Clear data';
  static const clearDataHelp =
      'Pick what to delete. Your ROM files, your settings and your '
      'RetroAchievements login are never touched.';
  static const clearEverything = 'Everything';
  static const clearScans = 'Scan results';
  static const clearScansCost =
      'Every hash, match and achievement count. Your whole library has '
      'to be re-scanned.';
  static const clearPlaylists = 'Playlists and favorite systems';
  static const clearPlaylistsCost =
      'Favorites, Played, Trash and anything you made yourself. Cull '
      'verdicts go with them, because that is where the deck files them.';
  static const clearCullVerdicts = 'Cull verdicts';
  static const clearCullVerdictsCost =
      'Which games the elimination game has judged. They are restored. '
      'Playlists keep whatever the verdicts put there.';
  static const clearScrapedData = 'Imported Skraper metadata';
  static const clearScrapedDataCost =
      'Box art and descriptions from gamelist.xml (Skraper). Re-importable from '
      'the same folder.';
  static const clearRaData = 'Downloaded RetroAchievements data';
  static const clearRaDataCost =
      'Cached game lists. Re-downloaded on the next fetch, so clear this '
      'if matches look wrong.';
  static const clearArtwork = 'Cached artwork';
  static const clearArtworkCost =
      'Covers and achievement icons. Re-downloaded on demand;';
  static const clearDataConfirm = 'Delete';

  // -- Credentials prompt
  static const credentialsMissing =
      'Set your RetroAchievements credentials in Settings first.';
}

/// Theme picker, mode toggle and UI scale.
abstract final class AppearanceStrings {
  // -- Mode toggle
  static const modeHelp =
      'Kiosk hides the maintenance tabs, scans, multi-select and every delete '
      'button, so the app is safe to hand over. A controller drives either mode.';
  static const modeCleaning = 'Cleaning';
  static const modeKiosk = 'Kiosk';
}

/// Theme names in the theme picker.
abstract final class ThemeStrings {
  static const retroAchievements = 'RetroAchievements';
  static const light = 'Light';
  static const oled = 'OLED';
  static const nord = 'Nord';
  static const github = 'GitHub';
  static const lavenderDark = 'Lavender Dark';
  static const gameboy = 'Game Boy';
  static const lavenderLight = 'Lavender Light';
  static const slate = 'Slate';
  static const monochrome = 'Monochrome';
  static String uiScale(double scale) => '${(scale * 100).round()}%';
}

/// Sort dropdown labels (library grid and folder view).
abstract final class SortStrings {
  static const name = 'Name';
  static const size = 'Size';
  static const files = 'Files';
  static const system = 'System';
  static const achievements = 'Achievements';
  static const progress = 'Progress';
  static const lastPlayed = 'Last played';
  static const leastPlayed = 'Least played';
}

/// ROM status wording and fetch outcomes shown on rows, chips and cells.
abstract final class RomStatusStrings {
  static const notFetched = 'Not fetched';
  static const checking = 'Checking...';
  static const supported = 'Supported';
  static const noAchievements = 'No achievements';
  static const badFormat = 'Bad format';
  static const error = 'Error';
  static const notOnRa = 'Not on RetroAchievements';
  static String gamePlaceholder(int? gameId) => 'Game #$gameId';
  static String hashFailed(int consoleId) =>
      'Could not hash file for console $consoleId';
  static const syncFailed = 'Progress sync failed. No changes made.';
  static const syncEmpty = 'No progress data returned. No changes made.';
  static const noConsoleMapping = 'no console mapping';
  static String consoleNotOnRa(String? console) =>
      "$console isn't on RetroAchievements";
  static const unknownSystem = 'Unknown';
  // Switch file parts.
  static const switchBase = 'Base';
  static const switchDlc = 'DLC';
  static String switchDlcNumbered(int n) => 'DLC $n';
  static const switchUpdate = 'Update';
  static String switchUpdateVersion(String version) => 'Update $version';
}

/// Built-in playlists and the favorites toggle message.
abstract final class BuiltinPlaylistStrings {
  static const favorites = 'Favorites';
  static const played = 'Played';
  static const wantToPlay = 'Want to Play';
  static const trash = 'Trash';
  static String addedToFavorites(int n) => 'added $n to Favorites';
  static String removedFromFavorites(int n) => 'removed $n from Favorites';
  static const noChanges = 'No changes';
}

/// Play Next shelf titles.
abstract final class PlayNextRowStrings {
  static const other = 'Other';
  static const allConsoles = 'All Consoles';
}

/// ROM tag chips parsed from file names.
abstract final class RomTagStrings {
  static const good = 'GOOD';
  static const hack = 'HACK';
  static const homebrew = 'HOMEBREW';
  static const subset = 'SUBSET';
  static const bonus = 'BONUS';
  static const proto = 'PROTO';
  static const beta = 'BETA';
  static const demo = 'DEMO';
  static const badDump = 'BAD DUMP';
  static const overdump = 'OVERDUMP';
  static const checksum = 'CHECKSUM';
  static const fixed = 'FIXED';
  static const pirate = 'PIRATE';
  static const trainer = 'TRAINER';
  static const badChecksum = 'BAD SUM';
  static const alternate = 'ALT';
  static const sram = 'SRAM';
  static const unlicensed = 'UNL';
}

/// Exported library reports (Markdown, CSV and PDF).
abstract final class ExportStrings {
  static const name = 'Name';
  static const hasAchievements = 'Has achievements';
  static const progress = 'Progress';
  static const size = 'Size';
  static const yes = 'Yes';
  static const no = 'No';
  static String systemTitle(String system) => '$system library';
  // Library health report.
  static const healthTitle = 'Library report';
  static const metric = 'Metric';
  static const count = 'Count';
  static const totalRoms = 'Total ROMs';
  static const supported = 'Supported';
  static const unsupported = 'Unsupported';
  static const notFetched = 'Not fetched';
  static const withProgress = 'With progress';
  static const systems = 'Systems';
  static const perSystem = 'Per system';
  static const system = 'System';
  static const games = 'Games';
  static const scanned = 'Scanned';
}
