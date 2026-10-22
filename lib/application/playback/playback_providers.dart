import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Bound at the composition root. Null means no player at all: the player
/// UI stays hidden rather than pretending to play.
final playbackControllerProvider = Provider<PlaybackController?>((ref) => null);

/// True when the bound controller is the silent demo player, so the UI can
/// say so.
final isDemoPlaybackProvider = Provider<bool>((ref) => false);

/// Current player state: the latest snapshot first, then every update.
final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  if (controller == null) return Stream.value(PlaybackSnapshot.initial);
  return () async* {
    yield controller.snapshot;
    yield* controller.snapshots;
  }();
});

/// Playback position, kept apart from [playbackSnapshotProvider] so only the
/// progress widgets rebuild on every tick.
final playbackPositionProvider = StreamProvider<Duration>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  if (controller == null) return Stream.value(Duration.zero);
  return () async* {
    yield controller.position;
    yield* controller.positions;
  }();
});
