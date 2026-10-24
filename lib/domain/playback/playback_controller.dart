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

  /// Replaces the queue. With [play] the first track starts as soon as it
  /// is ready (no paused moment in between).
  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool play = false,
  });

  /// Inserts [tracks] right after the current one. With an empty queue they
  /// become the queue (paused).
  Future<void> playNext(List<Track> tracks);

  /// Adds [tracks] at the end of the queue.
  Future<void> addToQueue(List<Track> tracks);

  /// Removes the track at [index] in the play order. The current track is
  /// not removed (skip it instead).
  Future<void> removeFromQueue(int index);

  /// Moves a track within the play order; the current track keeps playing.
  Future<void> moveInQueue(int from, int to);

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
