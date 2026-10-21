import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';

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
}
