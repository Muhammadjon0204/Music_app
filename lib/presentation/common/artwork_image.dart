import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/artwork_providers.dart';

/// The image for a stored artwork reference, or null to show the gradient
/// placeholder (no artwork, unresolvable reference, or web).
ImageProvider<Object>? artworkImage(WidgetRef ref, Uri? artwork) {
  if (artwork == null) return null;
  final path = ref.watch(artworkPathResolverProvider)(artwork);
  return path == null ? null : FileImage(File(path));
}
