import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';
import 'package:music_app/presentation/player/player_palette.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const c = AuraColors.dark;
  const textAA = 4.5;
  const nonTextAA = 3.0;

  final backgrounds = {
    'background': c.background,
    'surface': c.surface,
    'surfaceElevated': c.surfaceElevated,
  };
  final texts = {
    'textPrimary': c.textPrimary,
    'textSecondary': c.textSecondary,
    'textTertiary': c.textTertiary,
    'accentText': c.accentText,
    'error': c.error,
  };

  group('Text contrast meets WCAG AA (4.5:1)', () {
    for (final bg in backgrounds.entries) {
      for (final fg in texts.entries) {
        test('${fg.key} on ${bg.key}', () {
          expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(textAA));
        });
      }
    }

    test('onAccent on accent (primary button label)', () {
      expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(textAA));
    });
  });

  test('accent is visible as a UI element on background (3:1)', () {
    expect(contrast(c.accent, c.background), greaterThanOrEqualTo(nonTextAA));
  });

  group('Now Playing background keeps text readable for every artwork', () {
    for (final artwork in c.artworkGradients) {
      final background = nowPlayingBackground(artwork, c);

      test('title, artist and times over $artwork', () {
        // Text starts below the middle stop, which is the lightest point it
        // can sit on.
        for (final color in [c.textPrimary, c.textSecondary, c.textTertiary]) {
          expect(
            contrast(color, background[1]),
            greaterThanOrEqualTo(textAA),
            reason: '$color',
          );
        }
      });

      test('demo chip on the tinted top over $artwork', () {
        final chip = Color.alphaBlend(
          c.background.withValues(alpha: nowPlayingLabelBackdropAlpha),
          background[0],
        );
        expect(contrast(c.accentText, chip), greaterThanOrEqualTo(textAA));
      });

      test('close button on the tinted top over $artwork', () {
        expect(
          contrast(c.textPrimary, background[0]),
          greaterThanOrEqualTo(nonTextAA),
        );
      });
    }
  });

  // The featured banner puts text over an artwork gradient with a dark scrim
  // that grows to 75% at the bottom. The title (large text, 3:1) sits from
  // ~55% height down, the subtitle (small text, 4.5:1) from ~80%.
  test('banner text stays readable on every artwork gradient', () {
    const scrimMax = 0.75;
    for (final gradient in c.artworkGradients) {
      for (final color in gradient) {
        Color behind(double heightFraction) => Color.alphaBlend(
          c.background.withValues(alpha: scrimMax * heightFraction),
          color,
        );
        expect(
          contrast(c.textPrimary, behind(0.55)),
          greaterThanOrEqualTo(nonTextAA),
          reason: 'title on $color',
        );
        expect(
          contrast(c.textPrimary, behind(0.8)),
          greaterThanOrEqualTo(textAA),
          reason: 'subtitle on $color',
        );
      }
    }
  });
}
