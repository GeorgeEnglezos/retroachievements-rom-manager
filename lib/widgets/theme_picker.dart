import 'package:flutter/material.dart';
import '../services/app_theme.dart';
import '../theme/ui_tokens.dart';
import 'ui/ui_focusable.dart';

/// A swatch card per [AppTheme]; tapping one saves it and the app repaints.
/// Used by both Settings and the setup wizard.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: appThemeListenable,
      builder: (context, current, _) => Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final theme in AppTheme.values)
              _ThemeSwatch(
                theme: theme,
                selected: theme == current,
                onTap: () => appThemeListenable.save(theme),
              ),
          ],
        ),
      ),
    );
  }
}

/// One tappable palette card in the theme picker. Painted in the palette's own
/// colours so it previews the theme; the selection ring uses the *current*
/// theme's accent so it reads against the live UI.
class _ThemeSwatch extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ui = context.ui; // live theme, for the selection ring
    final t = theme.tokens; // this card's palette, for the preview
    final dots = [t.accent, t.supported, t.accentAlt, t.accentGames];
    return UiFocusZoom(
      child: InkWell(
        onTap: onTap,
        borderRadius: ui.roundMd,
        child: Container(
          width: 152,
          decoration: BoxDecoration(
            borderRadius: ui.roundMd,
            border: Border.all(
              color: selected ? ui.accent : t.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: ui.roundMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  width: double.infinity,
                  color: t.background,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      for (final c in dots)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: t.surface,
                  padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          theme.label,
                          style: t.body.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, size: 16, color: ui.accent),
                    ],
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
