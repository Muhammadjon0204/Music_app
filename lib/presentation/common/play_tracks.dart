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
  // Shuffle off first, so the new queue is built in order; play starts as
  // soon as the track is ready, without a paused moment in between.
  await controller.setShuffleEnabled(false);
  await controller.setQueue(tracks, startIndex: index, play: true);
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
  await controller.setQueue(tracks, startIndex: start, play: true);
  // Shuffles the rest; the starting track keeps playing.
  await controller.setShuffleEnabled(true);
}
