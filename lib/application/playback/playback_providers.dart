import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Null until the audio engine is implemented (Phase 6). While null, the
/// player UI stays hidden rather than pretending to play.
final playbackControllerProvider = Provider<PlaybackController?>((ref) => null);

/// Current player state: the latest snapshot first, then every update.
final playbackSnapshotProvider = StreamProvider<PlaybackSnapshot>((ref) {
  final controller = ref.watch(playbackControllerProvider);
  if (controller == null) return Stream.value(PlaybackSnapshot.initial);
  return () async* {
    yield controller.snapshot;
    yield* controller.snapshots;
  }();
});
