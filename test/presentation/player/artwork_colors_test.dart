import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/player/artwork_colors.dart';
import 'package:music_app/presentation/player/player_palette.dart';

/// An image whose top half is [top] and bottom half is [bottom].
Uint8List twoHalves(Color top, Color bottom, {int size = 4, int alpha = 255}) {
  final bytes = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final c = y < size / 2 ? top : bottom;
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      bytes[i] = (c.r * 255).round();
      bytes[i + 1] = (c.g * 255).round();
      bytes[i + 2] = (c.b * 255).round();
      bytes[i + 3] = alpha;
    }
  }
  return bytes;
}

void main() {
  group('artwork tint', () {
    test('reads the top and the bottom half', () {
      const red = Color(0xFFFF0000);
      const blue = Color(0xFF0000FF);
      expect(artworkTint(twoHalves(red, blue), 4, 4), [red, blue]);
    });

    test('a colorful detail outweighs gray', () {
      // One saturated pixel among gray ones pulls the average toward it
      // more than its share of the area.
      final bytes = twoHalves(const Color(0xFF808080), const Color(0xFF808080));
      bytes
        ..[0] = 255
        ..[1] = 0
        ..[2] = 0;
      final top = artworkTint(bytes, 4, 4)!.first;
      final plainShare = (255 + 128 * 7) / 8;
      expect(top.r * 255, greaterThan(plainShare));
    });

    test('nothing to read gives null', () {
      expect(artworkTint(Uint8List(0), 0, 0), isNull);
      expect(artworkTint(Uint8List(8), 4, 4), isNull);
      final clear = twoHalves(
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        alpha: 0,
      );
      expect(artworkTint(clear, 4, 4), isNull);
    });
  });

  // The cover can be any color; the text on Now Playing must stay readable
  // over it in every theme.
  group('Now Playing background over any cover', () {
    const palettes = {
      'neon': AuraColors.dark,
      'midnight': AuraColors.midnight,
      'rose': AuraColors.rose,
      'forest': AuraColors.forest,
    };
    final random = Random(17);
    final covers = [
      const Color(0xFFFFFFFF),
      const Color(0xFF000000),
      const Color(0xFFFFFF00),
      for (var i = 0; i < 200; i++)
        Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        ),
    ];

    for (final MapEntry(key: name, value: c) in palettes.entries) {
      test(name, () {
        for (final top in covers) {
          final bottom = covers[(covers.indexOf(top) * 7) % covers.length];
          final background = nowPlayingBackground([top, bottom], c);
          expect(
            contrastRatio(c.textPrimary, background[0]),
            greaterThanOrEqualTo(3),
            reason: 'close button over $top',
          );
          for (final text in [c.textPrimary, c.textSecondary, c.textTertiary]) {
            expect(
              contrastRatio(text, background[1]),
              greaterThanOrEqualTo(4.5),
              reason: '$text over $bottom',
            );
          }
        }
      });
    }

    test('the tint is kept when it is already readable', () {
      const c = AuraColors.dark;
      final mixed = readableTint(
        const Color(0xFF1F1747),
        c,
        minAlpha: 0.45,
        texts: [c.textPrimary],
        minContrast: 3,
      );
      expect(
        mixed,
        Color.alphaBlend(
          c.background.withValues(alpha: 0.45),
          const Color(0xFF1F1747),
        ),
      );
    });
  });

  group('equalizer', () {
    test('flat when not playing, moving within its box when playing', () {
      for (var i = 0; i < 3; i++) {
        expect(
          AuraEqualizer.heightOf(i, Duration.zero, active: false),
          AuraEqualizer.heightOf(i, const Duration(seconds: 3), active: false),
        );
      }
      final heights = {
        for (var ms = 0; ms < 3000; ms += 200)
          AuraEqualizer.heightOf(0, Duration(milliseconds: ms), active: true),
      };
      expect(heights.length, greaterThan(5));
      expect(heights.every((h) => h >= 0.35 && h <= 1), isTrue);
    });
  });
}
