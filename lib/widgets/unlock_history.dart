import 'package:flutter/material.dart';

import '../services/ra_service.dart' show RecentUnlock;
import '../services/recent_unlocks.dart';
import '../theme/ui_tokens.dart';
import 'ra_image.dart';

/// A compact "recent achievement unlocks" panel, shown on Home in every UX mode
/// (dashboard and couch). Loads its own data once from RA and is always visible:
/// it shows a spinner while loading and a short message when there is nothing to
/// show, so the container the design calls for is present in every state.
///
/// ponytail: self-loads on mount; there's no push from RA, so a just-earned
/// achievement appears next time Home is opened. Fine for a read-only panel.
class UnlockHistory extends StatefulWidget {
  /// Fixed width when placed in a side column (couch Home); null fills its slot.
  final double? width;

  /// Fill the parent's height and never scroll, showing only the rows that fit
  /// (couch Home, which must sit on one screen). Off: sizes to content, capped
  /// and scrollable, for the standard dashboard.
  final bool fillHeight;

  /// Test seam: skips the network and renders these directly.
  final List<RecentUnlock>? preview;

  const UnlockHistory({
    super.key,
    this.width,
    this.fillHeight = false,
    this.preview,
  });

  @override
  State<UnlockHistory> createState() => _UnlockHistoryState();
}

class _UnlockHistoryState extends State<UnlockHistory> {
  late final Future<List<RecentUnlock>> _future =
      widget.preview != null ? Future.value(widget.preview) : loadRecentUnlocks();

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return FutureBuilder<List<RecentUnlock>>(
      future: _future,
      builder: (context, snap) {
        final Widget body;
        if (snap.connectionState == ConnectionState.waiting) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else {
          final unlocks = snap.data ?? const <RecentUnlock>[];
          if (unlocks.isEmpty) {
            body = Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                snap.hasError
                    ? "Couldn't load unlocks."
                    : 'No recent unlocks yet. Earn achievements and they show up '
                        'here.',
                style: TextStyle(color: ui.muted, fontSize: 12),
              ),
            );
          } else {
            final list = ListView.separated(
              // Couch Home fills its column; the dashboard sizes to content and
              // caps its height. Both scroll so every unlock is reachable.
              shrinkWrap: !widget.fillHeight,
              padding: EdgeInsets.zero,
              itemCount: unlocks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _UnlockRow(unlock: unlocks[i]),
            );
            body = widget.fillHeight
                ? Expanded(child: list)
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: list,
                  );
          }
        }
        return _panel(context, body);
      },
    );
  }

  Widget _panel(BuildContext context, Widget body) {
    final ui = context.ui;
    final panel = Container(
      decoration: BoxDecoration(
        color: ui.surface,
        borderRadius: ui.roundMd,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: widget.fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text('RECENT UNLOCKS', style: ui.labelCaps),
          ),
          body,
        ],
      ),
    );
    return widget.width == null
        ? panel
        : SizedBox(width: widget.width, child: panel);
  }
}

class _UnlockRow extends StatelessWidget {
  final RecentUnlock unlock;
  const _UnlockRow({required this.unlock});

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaImage(
          url: unlock.badgeUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          borderRadius: ui.roundSm,
          placeholder: ColoredBox(color: ui.surfaceAlt),
          error: ColoredBox(
            color: ui.surfaceAlt,
            child: Icon(Icons.emoji_events, color: ui.muted, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unlock.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ui.text),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  unlock.gameTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: ui.muted),
                ),
              ),
              if (unlock.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    unlock.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: ui.text),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${unlock.points}',
            style: ui.labelCaps.copyWith(color: ui.accent, fontSize: 12)),
      ],
    );
  }
}
