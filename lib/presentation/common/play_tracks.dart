import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';

/// Plays [tracks] from [index] in order.
Future<void> playTracks(
  WidgetRef ref,
  List<Track> tracks, {
  int index = 0,
}) async {
  final controller = ref.read(playbackControllerProvider);
  if (controller == null || tracks.isEmpty) return;
  await controller.setQueue(tracks, startIndex: index);
  await controller.setShuffleEnabled(false);
  await controller.play();
}

/// Plays [tracks] shuffled, starting from a random one.
Future<void> shuffleTracks(
  WidgetRef ref,
  List<Track> tracks, {
  Random? random,
}) async {
  final controller = ref.read(playbackControllerProvider);
  if (controller == null || tracks.isEmpty) return;
  final start = (random ?? Random()).nextInt(tracks.length);
  await controller.setQueue(tracks, startIndex: start);
  await controller.setShuffleEnabled(true);
  await controller.play();
}
