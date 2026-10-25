import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:music_app/presentation/design_system/tokens/aura_colors.dart';

/// Side of the thumbnail the colors are read from: enough for the overall
/// mood of a cover, cheap to scan.
const artworkSampleSize = 24;

/// The two colors of a cover: the average of its top half and of its
/// bottom half, weighted toward saturated pixels so a colorful detail is
/// not washed out by gray. [rgba] is `width × height` RGBA bytes. Null for
/// an empty or fully transparent image.
List<Color>? artworkTint(Uint8List rgba, int width, int height) {
  if (width <= 0 || height <= 0 || rgba.length < width * height * 4) {
    return null;
  }
  Color? average(int fromRow, int toRow) {
    var r = 0.0, g = 0.0, b = 0.0, total = 0.0;
    for (var y = fromRow; y < toRow; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final a = rgba[i + 3] / 255;
        if (a == 0) continue;
        final pr = rgba[i], pg = rgba[i + 1], pb = rgba[i + 2];
        final hi = math.max(pr, math.max(pg, pb));
        final lo = math.min(pr, math.min(pg, pb));
        final saturation = hi == 0 ? 0.0 : (hi - lo) / hi;
        final weight = a * (0.25 + saturation);
        r += pr * weight;
        g += pg * weight;
        b += pb * weight;
        total += weight;
      }
    }
    if (total == 0) return null;
    return Color.fromARGB(
      255,
      (r / total).round(),
      (g / total).round(),
      (b / total).round(),
    );
  }

  final middle = math.max(1, height ~/ 2);
  final top = average(0, middle);
  final bottom = average(middle, height) ?? top;
  if (top == null || bottom == null) return null;
  return [top, bottom];
}

/// WCAG 2.x contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [tint] covered by the app background, as little as possible but enough
/// that every color in [texts] keeps [minContrast] on it. Works for dark
/// and light themes: the background always contrasts with the theme's text.
Color readableTint(
  Color tint,
  AuraColors colors, {
  required double minAlpha,
  required List<Color> texts,
  required double minContrast,
}) {
  for (var alpha = minAlpha; alpha < 1; alpha += 0.05) {
    final mixed = Color.alphaBlend(
      colors.background.withValues(alpha: alpha),
      tint,
    );
    if (texts.every((text) => contrastRatio(text, mixed) >= minContrast)) {
      return mixed;
    }
  }
  return colors.background;
}

/// Reads [image] at thumbnail size and returns its [artworkTint]. Null when
/// it cannot be loaded or read (e.g. a cover blocked from pixel access).
Future<List<Color>?> loadArtworkTint(ImageProvider<Object> image) async {
  final completer = Completer<ui.Image?>();
  final stream = ResizeImage(
    image,
    width: artworkSampleSize,
    height: artworkSampleSize,
    policy: ResizeImagePolicy.fit,
  ).resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  final decoded = await completer.future;
  if (decoded == null) return null;
  try {
    final bytes = await decoded.toByteData();
    if (bytes == null) return null;
    return artworkTint(
      bytes.buffer.asUint8List(),
      decoded.width,
      decoded.height,
    );
  } on Object {
    return null;
  } finally {
    decoded.dispose();
  }
}
