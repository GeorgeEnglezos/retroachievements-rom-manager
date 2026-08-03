import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/folder_stats.dart';
import '../services/console_image.dart';
import '../services/console_map.dart';
import '../theme/ui_tokens.dart';
import '../theme/ui_theme.dart';
import 'ui/console_card.dart';
import 'ui/ui_card.dart';
import 'ui/ui_progress_bar.dart';

// The console logos are full-color on transparency and don't tint to the theme,
// so cards render their contents through the light palette (dark ink) and use
// the [UiTokens.cardSurface] badge color so text stays legible on it.
final ThemeData _lightCardTheme = uiTheme(UiTokens.light);

// A grid tile for one subfolder. The front shows the console picture (or a
// fallback folder icon) and the name; hovering flips the card on its Y-axis to
// reveal the folder's stats on the back.
class FolderCard extends StatefulWidget {
  /// The raw folder name, shown on the back of the card.
  final String name;

  /// The label shown on the front of the card. Resolved by the caller from the
  /// active name mode, so it may be the full system name or the folder name.
  final String displayName;
  final FolderStats? stats;
  final int? consoleId;
  final String? subtitle;
  // Null disables the tap (e.g. while a scan is running).
  final VoidCallback? onTap;

  const FolderCard({
    super.key,
    required this.name,
    required this.displayName,
    required this.stats,
    required this.consoleId,
    this.subtitle,
    required this.onTap,
  });

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _hover(bool entered) {
    if (entered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the surface off the real theme before the light-theme override below
    // (white in dark, warm beige in light).
    final cardColor = context.ui.cardSurface;
    return Theme(
      data: _lightCardTheme,
      child: MouseRegion(
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final angle = _controller.value * math.pi; // 0..π
          final showBack = angle > math.pi / 2;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: showBack
                // Counter-rotate the back so its content isn't mirrored.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _face(color: cardColor, child: _back(context)),
                  )
                : _face(color: cardColor, child: _front(context)),
          );
        },
      ),
      ),
    );
  }

  // Shared card shell so both faces share size, elevation, tap target.
  Widget _face({required Color color, required Widget child}) {
    return UiCard(
      onTap: widget.onTap,
      color: color,
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _front(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ConsoleLogo(consoleId: widget.consoleId)),
        const SizedBox(height: 8),
        Text(
          widget.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (!ConsoleMap.isRaSupported(widget.consoleId)) ...[
          const SizedBox(height: 4),
          Align(alignment: Alignment.center, child: _unsupportedChip(context)),
        ],
      ],
    );
  }

  // Marks systems RA can't validate (Switch, PS3…, or an unidentified folder).
  Widget _unsupportedChip(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'No RetroAchievements',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.grey.shade800),
        ),
      );

  Widget _back(BuildContext context) {
    final s = widget.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const Spacer(),
        ..._folderStatLines(s),
        const SizedBox(height: 6),
        _Achievements(stats: s, consoleId: widget.consoleId),
      ],
    );
  }
}

/// The phone counterpart of [FolderCard]: the logo in the left column and, in
/// the right one, everything the card only reveals when a mouse hovers it.
/// Touch has no hover, so the flip is dropped rather than replaced.
class FolderRow extends StatelessWidget {
  /// The raw folder name; shown under [displayName] when the two differ.
  final String name;
  final String displayName;
  final FolderStats? stats;
  final int? consoleId;
  final String? subtitle;
  // Null disables the tap (e.g. while a scan is running).
  final VoidCallback? onTap;

  const FolderRow({
    super.key,
    required this.name,
    required this.displayName,
    required this.stats,
    required this.consoleId,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      // Built under ConsoleCard's light theme so the labels come out dark.
      child: Builder(
        builder: (context) => Row(
          children: [
            SizedBox(
                width: 76, height: 76, child: ConsoleLogo(consoleId: consoleId)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (name != displayName)
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  ..._folderStatLines(stats),
                  const SizedBox(height: 6),
                  _Achievements(stats: stats, consoleId: consoleId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The console's logo, or a generic one when the folder wasn't identified.
class ConsoleLogo extends StatelessWidget {
  final int? consoleId;

  const ConsoleLogo({super.key, required this.consoleId});

  @override
  Widget build(BuildContext context) {
    final tint = ConsoleImage.tintedLogos.contains(consoleId);
    return Image.asset(
      ConsoleImage.assetOrGeneric(consoleId),
      fit: BoxFit.contain,
      color: tint ? context.ui.text : null,
      colorBlendMode: tint ? BlendMode.srcIn : null,
      errorBuilder: (context, error, stack) => Center(
        child: Icon(Icons.folder,
            size: 48, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

List<Widget> _folderStatLines(FolderStats? s) => [
      _StatLine(
        icon: Icons.videogame_asset,
        text: s == null ? '…' : '${s.totalGames} games',
      ),
      const SizedBox(height: 4),
      _StatLine(
        icon: Icons.sd_storage,
        text: s == null ? '…' : formatBytes(s.totalSizeBytes),
      ),
    ];

class _StatLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _Achievements extends StatelessWidget {
  final FolderStats? stats;
  final int? consoleId;

  const _Achievements({required this.stats, required this.consoleId});

  @override
  Widget build(BuildContext context) {
    final pct = stats?.achievementPercent;
    if (pct == null) {
      return Text(
        ConsoleMap.isRaSupported(consoleId)
            ? 'Not scanned yet'
            : 'No RetroAchievements',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('With achievements',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Text('${pct.round()}%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        UiProgressBar(value: pct / 100, height: 8),
      ],
    );
  }
}
