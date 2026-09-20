import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rarm/services/app_theme.dart';
import 'package:rarm/theme/ui_tokens.dart';

import 'support/contrast.dart';

void main() {
  // Every shipped theme, keyed by its picker label, so a new AppTheme case is
  // held to the same geometry and WCAG invariants without editing this file.
  final palettes = {for (final t in AppTheme.values) t.label: t.tokens};

  test('no palette draws offset shadows', () {
    for (final ui in palettes.values) {
      expect(ui.cardShadow, Offset.zero);
      expect(ui.controlShadow, Offset.zero);
      expect(ui.shadow(), isEmpty);
      expect(ui.shadow(ui.controlShadow), isEmpty);
    }
  });

  test('every palette shares the rounded, hairline geometry', () {
    for (final ui in palettes.values) {
      expect(ui.borderWidth, 1);
      expect(ui.radius, 16);
      expect(ui.roundSm, BorderRadius.circular(10));
      expect(ui.roundMd, BorderRadius.circular(22));
      expect(ui.roundLg, BorderRadius.circular(28));
    }
  });

  test('accents expose five distinct hues per palette', () {
    for (final ui in palettes.values) {
      expect(ui.accents, hasLength(5));
      expect(ui.accents.toSet(), hasLength(5));
    }
  });

  test('dark is the RetroAchievements site scheme', () {
    const dark = UiTokens.dark;
    expect(dark.background, const Color(0xFF1A1A1A));
    expect(dark.surface, const Color(0xFF232323));
    expect(dark.surfaceAlt, const Color(0xFF2A2A2A));
    expect(dark.accent, const Color(0xFFCC9900));
    // Ink is the site's grey, not the gold: widgets that fill with one and
    // paint the other on top depend on the two staying different.
    expect(dark.text, const Color(0xFFC8C8C8));
    expect(dark.text, isNot(dark.accent));
  });

  // Contrast is asserted as a ratio, never as a hex, so retuning a palette
  // stays free as long as it stays legible. WCAG 2.1 asks 4.5:1 for body text
  // and 3:1 for the boundary of a UI component (1.4.11).
  palettes.forEach((name, ui) {
    test('$name ink clears AA on both grounds', () {
      final inks = {
        'text': ui.text,
        'muted': ui.muted,
        'accent': ui.accent,
        'accentAlt': ui.accentAlt,
        'accentGames': ui.accentGames,
        'supported': ui.supported,
        'warning': ui.warning,
      };
      // surfaceAlt is a real text ground, not just a hover tint: rows, active
      // tabs and the dashboard rails paint ink straight onto it.
      final grounds = {
        'background': ui.background,
        'surface': ui.surface,
        'surfaceAlt': ui.surfaceAlt,
      };
      for (final ground in grounds.entries) {
        for (final ink in inks.entries) {
          expect(
            contrastRatio(ink.value, ground.value),
            greaterThanOrEqualTo(4.5),
            reason: '$name ${ink.key} on ${ground.key}',
          );
        }
      }
    });

    test('$name border reads as a component boundary', () {
      // cardShadow and controlShadow are both Offset.zero, so the border is the
      // only thing separating a card, panel or dialog from its ground. If it
      // drops below 3:1 those edges stop existing for a lot of people.
      expect(
        contrastRatio(ui.border, ui.surface),
        greaterThanOrEqualTo(3.0),
        reason: '$name border on surface',
      );
    });
  });

  test('on-scrim inks clear AA against the scrim', () {
    // The scrim is theme-independent, so palette ink cannot be used on it:
    // light's olive accentGames lands at ~3:1. These three exist for that.
    for (final ink in [kOnScrim, kOnScrimMuted, kOnScrimAccent]) {
      expect(contrastRatio(ink, kScrim), greaterThanOrEqualTo(4.5));
    }
  });

  test('copyWith and lerp carry the new tokens', () {
    final wider = UiTokens.dark.copyWith(radius: 4, surfaceAlt: Colors.black);
    expect(wider.radius, 4);
    expect(wider.surfaceAlt, Colors.black);

    final mid = UiTokens.light.lerp(UiTokens.dark, 1);
    expect(mid.surfaceAlt, UiTokens.dark.surfaceAlt);
    expect(mid.accentAlt, UiTokens.dark.accentAlt);
  });
}
