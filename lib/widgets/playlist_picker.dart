import 'package:flutter/material.dart';
import '../services/playlist_store.dart';
import 'ui/ui_focusable.dart';

/// Played and Want to Play are fully re-derived on every library refresh (see
/// HomeScreen._refreshPlaylists), so a manual add/remove here would just be
/// silently overwritten on the next fetch. Disabled rather than hidden, so the
/// picker still shows a game's membership in them.
bool _isAutoManaged(String playlistId) =>
    playlistId == playedId || playlistId == wantToPlayId;

/// Asks for a new playlist name; null on cancel or empty input.
Future<String?> _promptPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  try {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New playlist'),
        content: UiFocusZoom(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name'),
          ),
        ),
        actions: [
          UiFocusZoom(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
          UiFocusZoom(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
    return (name == null || name.isEmpty) ? null : name;
  } finally {
    controller.dispose();
  }
}

/// Lets the user toggle a game's membership across playlists, and create a new
/// one. Operates on a single member key.
class PlaylistPicker extends StatefulWidget {
  final PlaylistStore store;
  final String memberKey;

  const PlaylistPicker({
    super.key,
    required this.store,
    required this.memberKey,
  });

  static Future<void> show(
    BuildContext context,
    PlaylistStore store,
    String memberKey,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => PlaylistPicker(store: store, memberKey: memberKey),
    );
  }

  static Future<void> showBulk(
    BuildContext context,
    PlaylistStore store,
    List<String> memberKeys,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BulkPlaylistPicker(store: store, memberKeys: memberKeys),
    );
  }

  @override
  State<PlaylistPicker> createState() => _PlaylistPickerState();
}

class _PlaylistPickerState extends State<PlaylistPicker> {
  List<Playlist> _playlists = [];
  Set<String> _member = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.all();
    final member = await widget.store.playlistsContaining(widget.memberKey);
    if (!mounted) return;
    setState(() {
      _playlists = all;
      _member = member;
    });
  }

  Future<void> _toggle(Playlist pl, bool on) async {
    if (on) {
      await widget.store.addMember(pl.id, widget.memberKey);
    } else {
      await widget.store.removeMember(pl.id, widget.memberKey);
    }
    await _load();
  }

  Future<void> _createNew() async {
    final name = await _promptPlaylistName(context);
    if (name == null) return;
    final pl = await widget.store.create(name);
    await widget.store.addMember(pl.id, widget.memberKey);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to playlist'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final pl in _playlists)
              UiFocusZoom(
                child: CheckboxListTile(
                  title: Text(pl.name),
                  subtitle: _isAutoManaged(pl.id)
                      ? const Text('Auto-managed')
                      : null,
                  value: _member.contains(pl.id),
                  onChanged: _isAutoManaged(pl.id)
                      ? null
                      : (v) => _toggle(pl, v ?? false),
                ),
              ),
            const Divider(),
            UiFocusZoom(
              child: ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist…'),
                onTap: _createNew,
              ),
            ),
          ],
        ),
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}

class _BulkPlaylistPicker extends StatefulWidget {
  final PlaylistStore store;
  final List<String> memberKeys;
  const _BulkPlaylistPicker({required this.store, required this.memberKeys});

  @override
  State<_BulkPlaylistPicker> createState() => _BulkPlaylistPickerState();
}

class _BulkPlaylistPickerState extends State<_BulkPlaylistPicker> {
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.store.all();
    if (!mounted) return;
    setState(() => _playlists = all);
  }

  Future<void> _addToPlaylist(Playlist pl) async {
    for (final key in widget.memberKeys) {
      await widget.store.addMember(pl.id, key);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _createNew() async {
    final name = await _promptPlaylistName(context);
    if (name == null) return;
    final pl = await widget.store.create(name);
    for (final key in widget.memberKeys) {
      await widget.store.addMember(pl.id, key);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Add ${widget.memberKeys.length} ROM${widget.memberKeys.length == 1 ? '' : 's'} to playlist',
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No playlists yet.'),
              ),
            for (final pl in _playlists)
              UiFocusZoom(
                child: ListTile(
                  title: Text(pl.name),
                  subtitle: _isAutoManaged(pl.id)
                      ? const Text('Auto-managed')
                      : null,
                  trailing: const Icon(Icons.playlist_add),
                  enabled: !_isAutoManaged(pl.id),
                  onTap: _isAutoManaged(pl.id)
                      ? null
                      : () => _addToPlaylist(pl),
                ),
              ),
            const Divider(),
            UiFocusZoom(
              child: ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New playlist…'),
                onTap: _createNew,
              ),
            ),
          ],
        ),
      ),
      actions: [
        UiFocusZoom(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}
