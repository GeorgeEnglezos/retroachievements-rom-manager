import 'package:flutter/material.dart';

import '../../models/folder_stats.dart' show compactCount;
import '../../models/rom_result.dart';
import '../../theme/ui_tokens.dart';
import '../ra_image.dart';
import '../ui/ui_progress_bar.dart';

/// The big-picture home's featured banner: full-bleed box art under a scrim,
/// with the game's title, a mastery readout and a Play affordance. Focusable, so
/// it's where controller focus lands first; A (ActivateIntent) opens the game.
class CouchHero extends StatefulWidget {
  final RomResult rom;
  final VoidCallback onOpen;
  final bool autofocus;
  final String eyebrow;

  const CouchHero({
    super.key,
    required this.rom,
    required this.onOpen,
    this.autofocus = false,
    this.eyebrow = 'CONTINUE PLAYING',
  });

  @override
  State<CouchHero> createState() => _CouchHeroState();
}

class _CouchHeroState extends State<CouchHero> {
  final _node = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  void _onFocus() {
    final f = _node.hasFocus;
    if (f) {
      Scrollable.ensureVisible(context,
          alignment: 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
    if (f != _focused) setState(() => _focused = f);
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final rom = widget.rom;
    // Big Picture always prefers the RA name (falling back to the file name only
    // when there is no real title); it ignores the play-mode file-name setting.
    final title = gameDisplayName(rom.gameTitle, rom.fileName);
    final total = rom.achievementCount ?? 0;
    final earned = rom.earnedAchievements ?? 0;
    final frac = total == 0 ? 0.0 : (earned / total).clamp(0.0, 1.0);
    final art = rom.boxArt;
    final meta = [
      rom.consoleName,
      if (total > 0) '$earned/$total achievements',
      if ((rom.numPlayersCasual ?? 0) > 0)
        '${compactCount(rom.numPlayersCasual!)} players',
    ].whereType<String>().join('   ·   ');
    // Kept short so Home's two banners plus the three cover rows fit one screen
    // without scrolling. FittedBox below scales the readout down to this height.
    final h = (MediaQuery.sizeOf(context).height * 0.24).clamp(180.0, 240.0);

    return FocusableActionDetector(
      focusNode: _node,
      autofocus: widget.autofocus,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onOpen();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: h,
          decoration: BoxDecoration(
            borderRadius: ui.roundLg,
            border: Border.all(
              color: _focused ? ui.accent : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: ui.roundLg,
            child: Stack(
              fit: StackFit.expand,
              children: [
                art != null
                    ? RaImage(url: raImageUrl(art), fit: BoxFit.cover)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [ui.accent, ui.accentAlt],
                          ),
                        ),
                      ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        kScrim.withValues(alpha: 0.95),
                        kScrim.withValues(alpha: 0.62),
                        kScrim.withValues(alpha: 0.08),
                      ],
                      stops: const [0, 0.5, 0.9],
                    ),
                  ),
                ),
                // FittedBox(scaleDown) guarantees the readout never overflows a
                // short banner (small windows, large text scale); it only ever
                // shrinks to fit, so at normal sizes it renders at full size.
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Eyebrow(widget.eyebrow),
                            const SizedBox(height: 14),
                            Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ui.display.copyWith(
                                    color: kOnScrim,
                                    fontSize: 40,
                                    height: 1.0)),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ui.mono.copyWith(
                                      color: kOnScrimMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ],
                            if (total > 0) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 300,
                                child: UiProgressBar(
                                  value: frac,
                                  height: 7,
                                  color: kOnScrimAccent,
                                  trough: kOnScrim.withValues(alpha: 0.25),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String label;
  const _Eyebrow(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kOnScrim.withValues(alpha: 0.14),
          borderRadius: UiTokens.pill,
          border: Border.all(color: kOnScrim.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: context.ui.labelCaps
                .copyWith(color: kOnScrimAccent, fontSize: 10, letterSpacing: 2)),
      );
}
