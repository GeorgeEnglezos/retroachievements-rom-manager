import 'package:flutter/material.dart';
import '../models/rom_group.dart';
import '../models/rom_result.dart';
import '../models/rom_row.dart';
import '../services/console_map.dart';
import '../services/game_lookup.dart';
import '../services/library.dart';
import '../services/member_key.dart';
import '../services/playlist_store.dart';
import '../services/rom_filter.dart';
import '../services/scan_settings.dart';
import '../widgets/playlist_toolbar.dart';
import '../widgets/rom_list_view.dart';
import '../widgets/row_display.dart';

class PlaylistView extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  final PlaylistStore playlistStore;
  // Injectable for tests; defaults to the shared instance.
  final Library? library;

  const PlaylistView({
    super.key,
    required this.playlistId,
    required this.playlistName,
    required this.playlistStore,
    this.library,
  });

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  late final Library _lib = widget.library ?? Library.instance;

  bool _loading = true;
  bool _grouped = false;
  final List<RomResult> _roms = [];
  RomFilter _filter = const RomFilter();
  List<Playlist> _allPlaylists = [];
  Map<String, Set<String>> _membership = {};

  List<String> get _availableGenres => availableGenres(_roms);
  List<String> get _availableTags => availableTags(_roms);
  List<RomResult> get _visibleRoms => visibleRoms(_roms, _filter, _membership);

  bool get _anyProgress => _roms.any((r) => r.earnedAchievements != null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Reads the flat search index, keeps this playlist's members, then loads each
  // needed system file once to build fully-populated RomResults.
  Future<void> _load() async {
    final all = await widget.playlistStore.all();
    final pl = all.firstWhere((p) => p.id == widget.playlistId,
        orElse: () => Playlist(
            id: widget.playlistId, name: widget.playlistName, builtin: false));

    final rows = await _lib.searchIndex();
    final members = rows.where((r) =>
        pl.members.contains(memberKeyFor(gameId: r.gameId, filePath: r.filePath)));

    final bySystem = <String, List<String>>{};
    for (final r in members) {
      bySystem.putIfAbsent(r.systemPath, () => []).add(r.filePath);
    }

    final roms = <RomResult>[];
    for (final entry in bySystem.entries) {
      final data = await _lib.load(entry.key);
      final byPath = {for (final g in data.games) g.filePath: g};
      for (final filePath in entry.value) {
        final game = byPath[filePath];
        if (game == null) continue;
        roms.add(romFromEntry(game, consoleId: data.consoleId));
      }
    }

    _allPlaylists = all;
    _membership = playlistMembership(_allPlaylists);
    if (!mounted) return;
    setState(() {
      _roms
        ..clear()
        ..addAll(roms);
      _loading = false;
    });
  }

  Map<String, List<RomResult>> _bySystem() {
    final map = <String, List<RomResult>>{};
    for (final r in _visibleRoms) {
      final name = ConsoleMap.nameFor(r.consoleId) ?? 'Unknown';
      map.putIfAbsent(name, () => []).add(r);
    }
    return map;
  }

  List<RomGroup> _buildSystemGroups() {
    final grouped = _bySystem();
    final names = grouped.keys.toList()..sort();
    return [
      for (final name in names)
        RomGroup(
          label: name,
          rows: grouped[name]!.map(RomRow.fromRom).toList(),
        ),
    ];
  }

  Future<void> _loadMembership() async {
    _allPlaylists = await widget.playlistStore.all();
    if (!mounted) return;
    setState(() => _membership = playlistMembership(_allPlaylists));
  }

  Future<void> _excludeRow(RomRow r) async {
    await ScanSettings.addExcludedFiles([r.filePath!]);
    if (!mounted) return;
    setState(() => _roms.removeWhere((x) => x.filePath == r.filePath));
    await _loadMembership();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlistName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                PlaylistToolbar(
                  filter: _filter,
                  availableGenres: _availableGenres,
                  availableTags: _availableTags,
                  showProgress: _anyProgress,
                  playlists: [
                    for (final pl in _allPlaylists) (id: pl.id, name: pl.name)
                  ],
                  grouped: _grouped,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onGroupedToggle: () => setState(() => _grouped = !_grouped),
                ),
                Expanded(
                  child: _visibleRoms.isEmpty
                      ? const Center(child: Text('No games match.'))
                      : RomListView(
                          rows: _grouped
                              ? const []
                              : _visibleRoms.map(RomRow.fromRom).toList(),
                          groups: _grouped ? _buildSystemGroups() : null,
                          display: RowDisplay.roms,
                          store: widget.playlistStore,
                          enableSelection: true,
                          onDeleteRow: (r) => _lib.deleteRom(r.filePath!),
                          onRowsRemoved: (removed) => setState(() {
                            final paths =
                                removed.map((r) => r.filePath).toSet();
                            _roms.removeWhere(
                                (x) => paths.contains(x.filePath));
                          }),
                          bulkFavorites: true,
                          bulkPlaylist: true,
                          onRowsExcluded: (rows) {
                            final paths = [for (final r in rows) r.filePath!];
                            setState(() => _roms.removeWhere(
                                (x) => paths.contains(x.filePath)));
                          },
                          onRowExcluded: _excludeRow,
                          onPlaylistChanged: _loadMembership,
                        ),
                ),
              ],
            ),
    );
  }
}
