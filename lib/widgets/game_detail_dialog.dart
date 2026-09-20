import 'dart:io';
import 'package:flutter/material.dart';
import '../models/folder_stats.dart' show compactCount;
import '../models/rom_result.dart';
import '../models/scraped_game.dart';
import '../services/credentials.dart';
import '../services/disc_grouping.dart';
import '../services/switch_grouping.dart';
import '../services/app_mode.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/console_image.dart';
import '../services/mastery_effort.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/ra_service.dart';
import '../services/rom_tap.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'confirm_recycle_dialog.dart';
import 'image_viewer.dart';
import 'ui/ui_badge.dart';
import 'ui/ui_card.dart';
import 'ui/ui_segmented.dart';
import 'ra_image.dart';
import 'rom_actions.dart';
import 'rom_progress.dart';

/// The label for a marked RetroAchievements type, or null for a standard
/// achievement. RA marks the achievements that finish a game as `progression`
/// (steps required) plus a `win_condition` (the finale); earning all of them is
/// what awards the "beaten" badge. `missable` is one a playthrough can put out
/// of reach. Pure and top-level so the set of RA type strings that count stays
/// unit-testable.
String? achievementTypeLabel(String? type) => switch (type) {
      'win_condition' => 'Win condition',
      'progression' => 'Progression',
      'missable' => 'Missable',
      _ => null,
    };

/// Whether a left click on [rom] has anything to open: an RA match, a local-only
/// row, or imported (Skraper) extras, which live outside [RomResult.status].
bool canOpenDetail(RomResult rom) =>
    rom.status == RomStatus.supported ||
    rom.isLocalOnly ||
    ScrapedStore.instance.get(rom.filePath) != null;

/// A plain click on [rom]: launch it, or open its details, per the saved tap
/// setting (see rom_tap.dart). Both ROM tiles and the screens that open the
/// dialog straight from a click funnel through here, so the setting reaches
/// every click on a game.
Future<void> openRomOnTap(
  BuildContext context,
  RomResult rom, {
  required PlaylistStore store,
  VoidCallback? onDeleted,
  VoidCallback? onPlaylistChanged,
  VoidCallback? onFetch,
}) async {
  if (romTapListenable.value == RomTapAction.play) {
    await RomActions(
      rom: rom,
      store: store,
      onDeleted: onDeleted,
      onPlaylistChanged: onPlaylistChanged,
      onFetch: onFetch,
    ).handle(context, 'play');
    return;
  }
  if (!canOpenDetail(rom)) return;
  await showDialog<void>(
    context: context,
    builder: (_) => GameDetailDialog(
      rom: rom,
      store: store,
      onDeleted: onDeleted,
      onPlaylistChanged: onPlaylistChanged,
      onFetch: onFetch,
      scraped: ScrapedStore.instance.get(rom.filePath),
    ),
  );
}

class GameDetailDialog extends StatefulWidget {
  final RomResult rom;
  final PlaylistStore? store;
  final VoidCallback? onDeleted;
  final VoidCallback? onPlaylistChanged;
  final VoidCallback? onFetch;
  // Multi-disc set (all discs of the game, sorted). When more than one, the
  // dialog shows a disc switcher; [rom] is the initially selected disc.
  final List<RomResult>? discs;
  // Per-disc fetch (multi-disc only); receives the selected disc.
  final void Function(RomResult rom)? onFetchDisc;

  /// Imported (Skraper) extras for this ROM, or null. Fills RA gaps and adds a
  /// local-image strip. Looked up by the caller from ScrapedStore.
  final ScrapedGame? scraped;

  const GameDetailDialog({
    super.key,
    required this.rom,
    this.store,
    this.onDeleted,
    this.onPlaylistChanged,
    this.onFetch,
    this.discs,
    this.onFetchDisc,
    this.scraped,
  });

  @override
  State<GameDetailDialog> createState() => _GameDetailDialogState();
}

class _GameDetailDialogState extends State<GameDetailDialog> {
  // Mutable copy so a per-disc delete can drop a disc without closing.
  late final List<RomResult> _discs = [...(widget.discs ?? [widget.rom])];
  // Open on the passed [rom] (the representative disc the tapped row shows) so
  // the dialog matches that row's box art instead of flashing an unmatched disc.
  late int _selected = _discs.indexOf(widget.rom).clamp(0, _discs.length - 1);
  RomResult get rom => _discs[_selected];
  bool get _multiDisc => _discs.length > 1;

  // A Switch title's files are parts of one game, not interchangeable discs.
  // Derived from the files themselves so callers pass nothing extra.
  bool get _switchTitle => _multiDisc && isSwitchFile(_discs.first.fileName);

  // Only a Switch title's base file boots: updates and DLC are content the
  // emulator loads through it. Play always targets the base, whichever part
  // the switcher has selected. [DiscGroup] sorts the base first.
  RomResult get _playTarget => _switchTitle ? _discs.first : rom;

  List<Achievement>? _achievements;
  bool _achievementsLoading = false;
  String? _achievementsError;
  bool _listView = false;
  bool _isFavorite = false;

  String get _memberKey =>
      memberKeyFor(gameId: rom.gameId, filePath: rom.filePath);

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.store?.isFavorite(_memberKey) ?? false;
    _loadAchievements();
  }

  // Switching disc resets the per-disc state (each disc has its own match /
  // progress) and reloads achievements for the newly selected file.
  void _selectDisc(int i) {
    if (i == _selected) return;
    setState(() {
      _selected = i;
      _achievements = null;
      _achievementsError = null;
      _achievementsLoading = false;
      _isFavorite = widget.store?.isFavorite(_memberKey) ?? false;
    });
    _loadAchievements();
  }

  Future<void> _toggleFavorite() async {
    final store = widget.store;
    if (store == null) return;
    await store.toggleMember(favoritesId, _memberKey);
    if (!mounted) return;
    widget.onPlaylistChanged?.call();
    Navigator.pop(context);
  }

  Future<void> _loadAchievements() async {
    if (rom.gameId == null || rom.status != RomStatus.supported) return;

    // Guard against a stale response for a disc the user already switched away
    // from overwriting the current disc's achievements.
    final gameId = rom.gameId!;
    bool current() => mounted && rom.gameId == gameId;
    _achievementsLoading = true;

    try {
      final creds = await savedCredentials();
      if (creds == null) {
        if (current()) {
          setState(() {
            _achievementsLoading = false;
            _achievementsError = 'Add RA credentials in Settings to load achievements';
          });
        }
        return;
      }

      final (username, apiKey) = creds;
      final service = RaService(username: username, apiKey: apiKey);
      final (info, progress) = await service.getGameInfoAndUserProgress(gameId);

      if (current()) {
        setState(() {
          // Scans skip this call (one request per matched ROM), so opening the
          // game is what fills in box art, screenshots, genre, developer and
          // publisher. Applied here and persisted below so it is fetched once,
          // not on every open.
          applyGameInfo(rom, info);
          applyProgress(rom, progress);
          _achievements = progress.achievements;
          _achievementsLoading = false;
        });
        await saveGameDetail(
          rom.filePath,
          info: info,
          progress: progress,
          library: Library.instance,
        );
      }
    } catch (_) {
      if (current()) {
        setState(() {
          _achievementsError = "Couldn't load achievements";
          _achievementsLoading = false;
        });
      }
    }
  }

  Future<void> _handle(String choice) async {
    switch (choice) {
      case 'fetch':
        // Per-disc fetch closes the modal (like single-ROM fetch);
        // reopen to fetch the next disc.
        if (widget.onFetchDisc != null) {
          widget.onFetchDisc!(rom);
        } else {
          widget.onFetch?.call();
        }
        if (mounted) Navigator.pop(context);
      case 'delete':
        // Multi-disc aware, so it can't go through RomActions.
        await _confirmDelete(ScaffoldMessenger.of(context));
      default:
        // Reveal, copy, google, ra and playlist behave exactly as they do on a
        // tile, down to the snackbar wording, so the tile owns them.
        await RomActions(
          rom: rom,
          store: widget.store ?? PlaylistStore(),
          onPlaylistChanged: widget.onPlaylistChanged,
        ).handle(context, choice);
    }
  }

  Future<void> _confirmDelete(ScaffoldMessengerState messenger) async {
    final ok = await confirmRecycleDialog(
        context, deleteConfirmMessage(name: rom.fileName));
    if (!ok || !mounted) return;
    final deleted = await Library.instance.deleteRom(rom.filePath);
    if (!mounted) return;
    if (!deleted) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete file")));
      return;
    }
    widget.onDeleted?.call();
    messenger.showSnackBar(SnackBar(content: Text(deletedConfirmation)));
    // Multi-disc: drop just this disc and stay open on the rest.
    if (_discs.length > 1) {
      setState(() {
        _discs.removeAt(_selected);
        if (_selected >= _discs.length) _selected = _discs.length - 1;
        _achievements = null;
        _isFavorite = widget.store?.isFavorite(_memberKey) ?? false;
      });
      _loadAchievements();
    } else {
      Navigator.pop(context);
    }
  }

  Widget _actionButton(String choice, IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: () => _handle(choice),
      ),
    );
  }

  Widget _buildActions() {
    final canOpenRa = rom.status == RomStatus.supported && rom.gameId != null;
    final showFetch = !rom.isLocalOnly &&
        rom.status != RomStatus.checking &&
        (widget.onFetch != null || widget.onFetchDisc != null);
    final showPlaylist = widget.store != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            children: [
              if (!gamingMode) ...[
                _actionButton(
                    'reveal', Icons.folder_open, 'Reveal in Explorer'),
                _actionButton('copy', Icons.copy, 'Copy path'),
              ],
              _actionButton('google', Icons.search, 'Search Google'),
              if (canOpenRa)
                _actionButton('ra', Icons.open_in_new, 'Open RA page'),
              if (showFetch && !gamingMode)
                _actionButton(
                  'fetch',
                  rom.status == RomStatus.supported
                      ? Icons.sync
                      : Icons.cloud_download_outlined,
                  rom.status == RomStatus.supported ? 'Sync progress' : 'Fetch',
                ),
              if (showPlaylist)
                _actionButton(
                    'playlist', Icons.playlist_add, 'Add to playlist…'),
            ],
          ),
        ),
        // Play sits beside Favorite; Delete keeps its own row so three labels
        // never have to share a narrow (phone) dialog width.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              Expanded(child: _playButton()),
              if (showPlaylist) ...[
                const SizedBox(width: 8),
                Expanded(child: _favoriteButton()),
              ],
            ],
          ),
        ),
        if (!gamingMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [Expanded(child: _deleteButton())]),
          ),
      ],
    );
  }

  // Same launch path as the tile context menu (emulator lookup, set-emulator
  // prompt, error snack) so both surfaces behave identically.
  Widget _playButton() {
    return FilledButton.icon(
      onPressed: () =>
          RomActions(rom: _playTarget, store: widget.store ?? PlaylistStore())
              .handle(context, 'play'),
      icon: const Icon(Icons.play_arrow, size: 18),
      label: const Text('Play (beta)'),
    );
  }

  Widget _favoriteButton() {
    if (_isFavorite) {
      return FilledButton.icon(
        onPressed: _toggleFavorite,
        icon: const Icon(Icons.favorite, size: 18),
        label: const Text('Favorited'),
        style: FilledButton.styleFrom(
          backgroundColor: kFavoriteColor,
          foregroundColor: Colors.white,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _toggleFavorite,
      icon: const Icon(Icons.favorite_border, size: 18),
      label: const Text('Favorite'),
      style: OutlinedButton.styleFrom(
        foregroundColor: kFavoriteColor,
        side: const BorderSide(color: kFavoriteColor),
      ),
    );
  }

  Widget _deleteButton() {
    return FilledButton.icon(
      onPressed: () => _handle('delete'),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Delete'),
      style: FilledButton.styleFrom(
        backgroundColor: kDangerColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Achievements only exist for hash-matched games; without them a side panel
  // would just be an empty card, so those roms keep the single column.
  bool get _hasAchievementPanel =>
      rom.status == RomStatus.supported && rom.gameId != null;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kBreakWide;
    return wide && _hasAchievementPanel
        ? _splitLayout(context)
        : _singleLayout(context);
  }

  Widget _singleLayout(BuildContext context) {
    return Dialog(
      backgroundColor: context.ui.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.ui.roundLg,
        side: BorderSide(color: context.ui.border, width: context.ui.borderWidth),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._artSection(),
              _buildInfo(context),
              const Divider(height: 1),
              _buildActions(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildAchievementGrid(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wide screens split the modal into two cards side by side: the game on the
  // left, your achievements on the right, each scrolling on its own.
  Widget _splitLayout(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 940,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _panel(
                key: const Key('gameDetailPanel'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._artSection(),
                    _buildInfo(context, withProgress: false),
                    const Divider(height: 1),
                    _buildActions(),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: _panel(
                key: const Key('gameAchievementsPanel'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rom.earnedAchievements != null) ...[
                        _buildProgressSection(context),
                        const SizedBox(height: 16),
                      ],
                      _buildAchievementGrid(context, sidePanel: true),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Key key, required Widget child}) => UiCard(
        key: key,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(child: child),
      );

  List<Widget> _artSection() => [_buildBoxArt(), _buildThumbnails()];

  Widget _buildInfo(BuildContext context, {bool withProgress = true}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              _switchTitle
                  ? switchDisplayTitle(_discs.first.fileName)
                  : gameDisplayName(rom.gameTitle,
                      _multiDisc ? stripDiscToken(rom.fileName) : rom.fileName),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          if (rom.consoleName != null)
            Text(rom.consoleName!,
                style: Theme.of(context).textTheme.bodySmall),
          if (rom.lowConfidenceMatch)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 14, color: context.ui.muted),
                  const SizedBox(width: 4),
                  Text('Unverified name match',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.ui.muted)),
                ],
              ),
            ),
          if (_multiDisc) _buildDiscSwitcher(context),
          // Full RA stats/progress only for hash-matched games. Third-party
          // metadataOnly rows show the meta rows without the achievement UI;
          // local-only rows show neither.
          if (rom.status == RomStatus.supported) ...[
            const SizedBox(height: 16),
            _buildStats(context),
            const Divider(height: 28),
            _buildMetaRows(context),
            if (rom.earnedAchievements != null && withProgress) ...[
              const Divider(height: 28),
              _buildProgressSection(context),
            ],
          ] else if (rom.status == RomStatus.metadataOnly) ...[
            const SizedBox(height: 16),
            _buildMetaRows(context),
          ] else if (widget.scraped != null) ...[
            const SizedBox(height: 16),
            _buildMetaRows(context),
          ],
        ],
      ),
    );
  }

  Widget _buildBoxArt() {
    if (rom.isLocalOnly) {
      return _scrapedBoxArt() ??
          Container(
            height: 160,
            color: context.ui.trough,
            padding: const EdgeInsets.all(24),
            child: Image.asset(
              ConsoleImage.assetOrGeneric(rom.consoleId),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(Icons.videogame_asset,
                  size: 64, color: context.ui.muted),
            ),
          );
    }
    if (rom.boxArt == null) {
      return _scrapedBoxArt() ??
          Container(
            height: 160,
            color: context.ui.trough,
            child:
                Icon(Icons.videogame_asset, size: 64, color: context.ui.muted),
          );
    }
    return RaImage(
      url: raImageUrl(rom.boxArt!),
      height: 160,
      fit: BoxFit.contain,
      zoomable: true,
      error: Container(
        height: 160,
        color: context.ui.trough,
        child: Icon(Icons.broken_image, size: 64, color: context.ui.muted),
      ),
    );
  }

  // Imported box art from disk, used only when RA supplies none. Returns null
  // when there's no scraped box art so callers fall back to the console asset /
  // placeholder.
  Widget? _scrapedBoxArt() {
    final path = widget.scraped?.images['boxart'];
    if (path == null) return null;
    return _localImage(path, height: 160);
  }

  // One imported image from disk, tap-to-zoom like RA art (RaImage handles only
  // URLs, so local files wire the shared viewer themselves).
  Widget _localImage(String path,
          {double? width,
          double? height,
          BoxFit fit = BoxFit.contain,
          double errorIconSize = 64}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showImageViewer(context, FileImage(File(path))),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => Container(
            width: width,
            height: height,
            color: context.ui.trough,
            child: Icon(Icons.broken_image,
                size: errorIconSize, color: context.ui.muted),
          ),
        ),
      );

  // RA title/in-game screenshots and imported Skraper images (every imported
  // type except box art, handled in _buildBoxArt, and video, not rendered) share
  // one strip of 120x90 thumbnails that wraps to multiple rows when there are
  // many. Box art stays on its own above.
  Widget _buildThumbnails() {
    final s = widget.scraped;
    final scrapedKeys = s == null
        ? const <String>[]
        : (s.images.keys.where((k) => k != 'boxart' && k != 'video').toList()
          ..sort());

    final tiles = <Widget>[
      for (final shot in [rom.imageTitle, rom.imageIngame].whereType<String>())
        RaImage(
          url: raImageUrl(shot),
          width: 120,
          height: 90,
          fit: BoxFit.cover,
          zoomable: true,
          error: Container(
            width: 120,
            height: 90,
            color: context.ui.trough,
            child: Icon(Icons.broken_image, size: 32, color: context.ui.muted),
          ),
        ),
      for (final k in scrapedKeys)
        _localImage(s!.images[k]!,
            width: 120, height: 90, fit: BoxFit.cover, errorIconSize: 32),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: tiles),
    );
  }

  Widget _buildDiscSwitcher(BuildContext context) {
    // Discs are numbered; a Switch title's parts are named (Base / Update /
    // DLC), since which one you are looking at is not a number.
    final labels = _switchTitle
        ? switchPartLabels([for (final d in _discs) d.fileName])
        : [
            for (var i = 0; i < _discs.length; i++)
              'Disc ${discNumber(_discs[i].fileName) ?? i + 1}',
          ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: UiSegmented<int>(
              value: _selected,
              onChanged: _selectDisc,
              segments: [
                for (var i = 0; i < _discs.length; i++)
                  (value: i, label: labels[i], icon: null),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
              _switchTitle && switchPart(rom.fileName) != SwitchPart.base
                  ? 'File ${_selected + 1} of ${_discs.length} · installed '
                      'content, the base game is what boots'
                  : 'File ${_selected + 1} of ${_discs.length}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _stat(context, '${rom.achievementCount ?? 0}', 'Achievements'),
        if ((rom.points ?? 0) > 0) _stat(context, '${rom.points}', 'Points'),
        _stat(context, _fmt(rom.numPlayersCasual), 'Players'),
      ],
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildMetaRows(BuildContext context) {
    final s = widget.scraped;
    final rows = <(String, String?)>[
      ('Developer', raOrScraped(rom.developer, s?.developer)),
      ('Publisher', raOrScraped(rom.publisher, s?.publisher)),
      ('Genre', raOrScraped(rom.genre, s?.genre)),
      ('Released', raOrScraped(rom.released, s?.releaseDate)),
      ('Players', s?.players),
      ('Rating', s?.rating),
      ('Set released', rom.setCreated != null ? _fmtDate(rom.setCreated!) : null),
      ('Set updated', rom.setUpdated != null ? _fmtDate(rom.setUpdated!) : null),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          if (value != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            )),
                  ),
                  Expanded(
                    child: Text(value,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your progress',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        RomProgress(rom: rom, barHeight: 8, labelSize: 13, labelWeight: FontWeight.w600),
        if (RomProgress.masteryHint(rom) case final hint?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        if (rom.lastPlayed != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Last played: ${_fmtDate(rom.lastPlayed!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildAchievementGrid(BuildContext context,
      {bool sidePanel = false}) {
    if (_achievementsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_achievementsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _achievementsError!,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.ui.muted),
        ),
      );
    }

    final list = _achievements;
    if (list == null || list.isEmpty) {
      if (!sidePanel) return const SizedBox.shrink();
      // The side panel is a card of its own, so it needs something to show.
      return Text('No achievements in this set',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.ui.muted));
    }

    final effort = masteryEffort(list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!sidePanel) const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Achievements',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            UiSegmented<bool>(
              value: _listView,
              onChanged: (v) => setState(() => _listView = v),
              segments: const [
                (value: false, label: '', icon: Icons.grid_view),
                (value: true, label: '', icon: Icons.view_list),
              ],
            ),
          ],
        ),
        if (effort > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Effort to master: ~$effort RetroPoints still to earn',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        if (_listView)
          Column(children: list.map(_buildBadgeRow).toList())
        else
          // Grow each tile so a whole number of columns fills the panel width
          // edge to edge, leaving no ragged gap on the right.
          LayoutBuilder(builder: (context, c) {
            const spacing = 6.0;
            const target = 56.0;
            final cols =
                ((c.maxWidth + spacing) / (target + spacing)).floor().clamp(1, 99);
            final size = (c.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: list.map((a) => _buildBadgeTile(a, size)).toList(),
            );
          }),
      ],
    );
  }

  /// The marker for a typed achievement: the win condition that finishes the
  /// game, a progression step on the way there, or a missable one. Null for
  /// standard achievements. The win condition borrows the same accent as the
  /// "Beaten" badge shown elsewhere so the two read as one idea.
  ({
    String label,
    String mark,
    IconData? icon,
    String? emoji,
    Color color,
    double ring
  })? _typeMarker(Achievement a) {
    final label = achievementTypeLabel(a.type);
    if (label == null) return null;
    final ui = context.ui;
    // The win condition finishes the game: gold (the app's mastery/completion
    // accent), a crown, and a thicker ring so it clearly outranks the
    // progression steps, which get a lighter flag. No Material crown glyph
    // exists, so the crown is an emoji (gold in both themes). Missable is a
    // caution, not a rank, so it takes the danger red.
    return switch (a.type) {
      'win_condition' => (
          label: label,
          mark: '★',
          emoji: '👑',
          icon: null,
          color: ui.warning,
          ring: 3,
        ),
      'missable' => (
          label: label,
          mark: '⚠',
          emoji: null,
          icon: Icons.warning_amber_rounded,
          color: kDangerColor,
          ring: 2,
        ),
      _ => (
          label: label,
          mark: '★',
          emoji: null,
          icon: Icons.flag_outlined,
          color: ui.accent,
          ring: 2,
        ),
    };
  }

  // media.retroachievements.org badge (locked variant when unearned).
  String _badgeUrl(Achievement a) =>
      'https://media.retroachievements.org/Badge/'
      '${a.badgeName}${a.isEarned ? '' : '_lock'}.png';

  Widget _badgeImage(Achievement a, double size) => RaImage(
        url: _badgeUrl(a),
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: context.ui.roundSm,
        error: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.ui.trough,
            borderRadius: context.ui.roundSm,
          ),
          child: Icon(Icons.emoji_events,
              size: size / 2, color: context.ui.muted),
        ),
      );

  Widget _buildBadgeRow(Achievement achievement) {
    final image = _badgeImage(achievement, 40);
    final marker = _typeMarker(achievement);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Opacity(
        opacity: achievement.isEarned ? 1 : 0.5,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(achievement.title,
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (marker != null)
                        UiBadge(label: marker.label, color: marker.color),
                    ],
                  ),
                  if (achievement.description.isNotEmpty)
                    Text(achievement.description,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${achievement.points} pts',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTile(Achievement achievement, double size) {
    final image = _badgeImage(achievement, size);
    final marker = _typeMarker(achievement);
    Widget tile =
        achievement.isEarned ? image : Opacity(opacity: 0.5, child: image);

    if (marker != null) {
      final ui = context.ui;
      tile = Stack(
        clipBehavior: Clip.none,
        children: [
          // A colour ring frames the beaten-defining badge so it stands out
          // from the standard achievements around it; the win condition rings
          // thicker in gold. Painted as foregroundDecoration (over the badge, no
          // added size) so ringed tiles stay 48px and align with plain ones.
          Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: ui.roundSm,
              border: Border.all(color: marker.color, width: marker.ring),
            ),
            child: tile,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: ui.surface,
                shape: BoxShape.circle,
                border: Border.all(color: marker.color, width: 1),
              ),
              child: marker.emoji != null
                  ? Text(marker.emoji!, style: const TextStyle(fontSize: 11))
                  : Icon(marker.icon, size: 12, color: marker.color),
            ),
          ),
        ],
      );
    }

    return Tooltip(message: _tooltipText(achievement), child: tile);
  }

  String _tooltipText(Achievement a) {
    final buf = StringBuffer();
    buf.writeln(a.title);
    if (a.description.isNotEmpty) buf.writeln(a.description);
    if (_typeMarker(a) case final m?) buf.writeln('${m.mark} ${m.label}');
    buf.write('${a.points} pts');
    if (a.isEarned) buf.write(' · Earned ${_fmtDate(a.dateEarned!)}');
    buf.write('\n${_fmt(a.numAwarded)} players earned this');
    return buf.toString();
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day} ${dt.year}';
  }

  String _fmt(int? n) => n == null ? '0' : compactCount(n);
}
