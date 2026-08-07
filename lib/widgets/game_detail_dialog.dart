import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/rom_result.dart';
import '../models/scraped_game.dart';
import '../services/credentials.dart';
import '../services/disc_grouping.dart';
import '../services/file_actions.dart';
import '../services/library.dart';
import '../services/console_image.dart';
import '../services/mastery_effort.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/ra_service.dart';
import '../services/scraper/scraped_store.dart';
import '../theme/ui_tokens.dart';
import 'confirm_recycle_dialog.dart';
import 'image_viewer.dart';
import 'ui/ui_segmented.dart';
import 'playlist_picker.dart';
import 'ra_image.dart';
import 'rom_actions.dart';
import 'rom_progress.dart';

/// Whether a left click on [rom] has anything to open: an RA match, a local-only
/// row, or imported (Skraper) extras, which live outside [RomResult.status].
bool canOpenDetail(RomResult rom) =>
    rom.status == RomStatus.supported ||
    rom.isLocalOnly ||
    ScrapedStore.instance.get(rom.filePath) != null;

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
      final (_, progress) = await service.getGameInfoAndUserProgress(gameId);

      if (current()) {
        setState(() {
          _achievements = progress.achievements;
          _achievementsLoading = false;
        });
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
    final messenger = ScaffoldMessenger.of(context);
    void snack(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));

    switch (choice) {
      case 'reveal':
        if (!await FileActions.revealInExplorer(rom.filePath)) {
          snack("Couldn't reveal file");
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: rom.filePath));
        snack('Path copied');
      case 'fetch':
        // Per-disc fetch closes the modal (like single-ROM fetch);
        // reopen to fetch the next disc.
        if (widget.onFetchDisc != null) {
          widget.onFetchDisc!(rom);
        } else {
          widget.onFetch?.call();
        }
        if (mounted) Navigator.pop(context);
      case 'google':
        if (!await FileActions.openUrl(
            FileActions.googleSearchUrl(rom.filePath))) {
          snack("Couldn't open browser");
        }
      case 'ra':
        if (rom.gameId != null &&
            !await FileActions.openUrl(FileActions.raGameUrl(rom.gameId!))) {
          snack("Couldn't open browser");
        }
      case 'playlist':
        if (!mounted) return;
        await PlaylistPicker.show(context, widget.store!, _memberKey);
        widget.onPlaylistChanged?.call();
      case 'delete':
        await _confirmDelete(messenger);
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
              _actionButton('reveal', Icons.folder_open, 'Reveal in Explorer'),
              _actionButton('copy', Icons.copy, 'Copy path'),
              _actionButton('google', Icons.search, 'Search Google'),
              if (canOpenRa)
                _actionButton('ra', Icons.open_in_new, 'Open RA page'),
              if (showFetch)
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
      onPressed: () => RomActions(rom: rom, store: widget.store ?? PlaylistStore())
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.ui.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: context.ui.border, width: context.ui.borderWidth),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBoxArt(),
              _buildScreenshots(),
              _buildScrapedImages(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        gameDisplayName(
                            rom.gameTitle,
                            _multiDisc
                                ? stripDiscToken(rom.fileName)
                                : rom.fileName),
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
                            Icon(Icons.help_outline,
                                size: 14, color: context.ui.muted),
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
                    // Full RA stats/progress only for hash-matched games. Third-
                    // party metadataOnly rows show the meta rows without the
                    // achievement UI; local-only rows show neither.
                    if (rom.status == RomStatus.supported) ...[
                      const SizedBox(height: 16),
                      _buildStats(context),
                      const Divider(height: 28),
                      _buildMetaRows(context),
                      if (rom.earnedAchievements != null) ...[
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
              ),
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

  // Title-screen and in-game screenshots RA provides, shown as a strip under the
  // box art. Rendered only when at least one is present.
  Widget _buildScreenshots() {
    final shots = [rom.imageTitle, rom.imageIngame].whereType<String>().toList();
    if (shots.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: shots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => RaImage(
          url: raImageUrl(shots[i]),
          width: 120,
          fit: BoxFit.cover,
          zoomable: true,
          error: Container(
            width: 120,
            color: context.ui.trough,
            child: Icon(Icons.broken_image, size: 32, color: context.ui.muted),
          ),
        ),
      ),
    );
  }

  // Local Skraper images rendered from disk: every imported image type except
  // box art (handled in _buildBoxArt) and video (not rendered). Sorted for a
  // stable order across whatever media folders the scrape provided.
  Widget _buildScrapedImages() {
    final s = widget.scraped;
    if (s == null) return const SizedBox.shrink();
    final keys = s.images.keys
        .where((k) => k != 'boxart' && k != 'video')
        .toList()
      ..sort();
    final paths = [for (final k in keys) s.images[k]!];
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _localImage(paths[i],
            width: 120, fit: BoxFit.cover, errorIconSize: 32),
      ),
    );
  }

  Widget _buildDiscSwitcher(BuildContext context) {
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
                  (
                    value: i,
                    label: 'Disc ${discNumber(_discs[i].fileName) ?? i + 1}',
                    icon: null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('File ${_selected + 1} of ${_discs.length}',
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
        if ((rom.numPlayersHardcore ?? 0) > 0)
          _stat(context, _fmt(rom.numPlayersHardcore), 'Hardcore'),
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

  // RA value wins, but only when non-empty; an empty RA field falls through to
  // the scraped value.
  String? _gap(String? ra, String? scraped) =>
      (ra != null && ra.isNotEmpty) ? ra : scraped;

  Widget _buildMetaRows(BuildContext context) {
    final s = widget.scraped;
    final rows = <(String, String?)>[
      ('Developer', _gap(rom.developer, s?.developer)),
      ('Publisher', _gap(rom.publisher, s?.publisher)),
      ('Genre', _gap(rom.genre, s?.genre)),
      ('Released', _gap(rom.released, s?.releaseDate)),
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

  Widget _buildAchievementGrid(BuildContext context) {
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
              ?.copyWith(color: Colors.grey),
        ),
      );
    }

    final list = _achievements;
    if (list == null || list.isEmpty) return const SizedBox.shrink();

    final effort = masteryEffort(list);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
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
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: list.map(_buildBadgeTile).toList(),
          ),
      ],
    );
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
        borderRadius: BorderRadius.circular(4),
        error: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.emoji_events, size: size / 2, color: Colors.grey),
        ),
      );

  Widget _buildBadgeRow(Achievement achievement) {
    final image = _badgeImage(achievement, 40);

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
                  Text(achievement.title,
                      style: Theme.of(context).textTheme.bodyMedium),
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

  Widget _buildBadgeTile(Achievement achievement) {
    final image = _badgeImage(achievement, 48);

    return Tooltip(
      message: _tooltipText(achievement),
      child: achievement.isEarned ? image : Opacity(opacity: 0.5, child: image),
    );
  }

  String _tooltipText(Achievement a) {
    final buf = StringBuffer();
    buf.writeln(a.title);
    if (a.description.isNotEmpty) buf.writeln(a.description);
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

  String _fmt(int? n) {
    if (n == null || n == 0) return '0';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
