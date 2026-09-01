import 'package:flutter/material.dart';

import '../models/folder_stats.dart' show compactCount, formatBytes;
import '../services/home_dashboard.dart';
import '../theme/ui_tokens.dart';

/// The Home dashboard's at-a-glance counts. On a wide window the tiles size to
/// their content and wrap; on a phone ([narrow]) they lock to two equal columns
/// so the strip reads as a grid instead of a ragged flow.
class DashboardStatStrip extends StatelessWidget {
  final DashboardStats stats;
  final bool narrow;

  const DashboardStatStrip({
    super.key,
    required this.stats,
    this.narrow = false,
  });

  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final tiles = <({String value, String label, Color? color})>[
      (value: '${stats.totalGames}', label: 'Games', color: null),
      (value: '${stats.mastered}', label: 'Mastered', color: ui.accentGames),
      (
        value: compactCount(stats.achievementsEarned),
        label: 'Achievements earned',
        color: null
      ),
      (
        value: formatBytes(stats.totalSizeBytes),
        label: 'Library size',
        color: null
      ),
      (value: '${stats.systems}', label: 'Systems', color: null),
    ];

    return Padding(
      padding: EdgeInsets.only(top: narrow ? 16 : 20),
      child: LayoutBuilder(builder: (context, c) {
        // Two columns on a phone, and the odd tile out spans the full row so
        // the block ends square instead of half-empty.
        final half = (c.maxWidth - _gap) / 2;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var i = 0; i < tiles.length; i++)
              DashboardStatTile(
                value: tiles[i].value,
                label: tiles[i].label,
                color: tiles[i].color,
                width: !narrow
                    ? null
                    : (i == tiles.length - 1 && tiles.length.isOdd
                        ? c.maxWidth
                        : half),
              ),
          ],
        );
      }),
    );
  }
}

/// One count in [DashboardStatStrip]. A null [width] sizes to content.
class DashboardStatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final double? width;

  const DashboardStatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      width: width,
      constraints:
          width == null ? const BoxConstraints(minWidth: 150) : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: ui.surface,
        borderRadius: ui.roundLg,
        border: Border.all(
          color: color != null
              ? Color.alphaBlend(color!.withValues(alpha: 0.4), ui.border)
              : ui.border,
          width: ui.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ui.display.copyWith(fontSize: 26, color: color ?? ui.text)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: ui.muted)),
        ],
      ),
    );
  }
}
