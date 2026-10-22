import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/artwork_providers.dart';
import 'package:music_app/presentation/common/fallback_network_image.dart';

/// The image for a track's artwork: an online cover (HTTPS, cached in
/// memory for the session only), a library file, or null to show the
/// gradient placeholder. A cover that fails to load also shows it.
///
/// [alternatives] are the same cover on other hosts, tried in order.
ImageProvider<Object>? artworkImage(
  WidgetRef ref,
  Uri? artwork, {
  List<Uri> alternatives = const [],
}) {
  if (artwork == null) return null;
  if (artwork.isScheme('https')) {
    return FallbackNetworkImage([artwork, ...alternatives]);
  }
  final path = ref.watch(artworkPathResolverProvider)(artwork);
  return path == null ? null : FileImage(File(path));
}
