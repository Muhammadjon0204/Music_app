import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// The single entry point the UI uses to control playback. The mini player,
/// Now Playing and the queue all read from and send commands to one instance.
///
/// Implemented by the audio layer. Expected failures (missing file,
/// unsupported format) are published via [PlaybackSnapshot.failure] rather
/// than thrown; methods throw only on programming errors such as an
/// out-of-range index.
abstract interface class PlaybackController {
  PlaybackSnapshot get snapshot;

  Stream<PlaybackSnapshot> get snapshots;

  /// Current position within the current track.
  Duration get position;

  /// High-frequency position updates, separate from [snapshots].
  Stream<Duration> get positions;

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0});

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> skipToNext();

  Future<void> skipToPrevious();

  /// Jumps to [index] in the play order ([PlaybackSnapshot.queue]).
  Future<void> skipToIndex(int index);

  Future<void> setShuffleEnabled(bool enabled);

  Future<void> setRepeatMode(PlaybackRepeatMode mode);

  Future<void> dispose();
}
