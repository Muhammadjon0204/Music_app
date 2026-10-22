import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/track.dart';

/// What the player is doing, as confirmed by the audio engine.
enum PlaybackStatus {
  /// Nothing queued.
  idle,

  /// The track is being resolved or opened.
  loading,

  /// Opened and meant to play, but waiting for data (slow stream).
  buffering,

  /// The engine reports sound is playing.
  playing,

  /// Stopped by the user or the system (call, headphones unplugged).
  paused,

  /// The queue ended.
  completed,

  /// The current track cannot play; see [PlaybackSnapshot.failure].
  failed,
}

enum PlaybackRepeatMode { off, all, one }

/// Immutable player state, excluding playback position.
///
/// Position changes many times per second, so it is published on a separate
/// stream (see PlaybackController.positions) to avoid rebuilding the whole
/// player UI on every tick.
///
/// [queue] is in play order (shuffled when shuffle is on), which is what
/// the queue screen shows.
final class PlaybackSnapshot {
  PlaybackSnapshot({
    required List<Track> queue,
    this.currentIndex,
    this.status = PlaybackStatus.idle,
    bool? playWhenReady,
    this.shuffleEnabled = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.duration,
    this.failure,
  }) : queue = List.unmodifiable(queue),
       playWhenReady =
           playWhenReady ??
           (status == PlaybackStatus.playing ||
               status == PlaybackStatus.buffering) {
    final index = currentIndex;
    if (index != null && (index < 0 || index >= this.queue.length)) {
      throw RangeError.index(index, this.queue, 'currentIndex');
    }
  }

  static final PlaybackSnapshot initial = PlaybackSnapshot(queue: const []);

  final List<Track> queue;
  final int? currentIndex;
  final PlaybackStatus status;

  /// The user wants sound: true while loading or buffering a track that
  /// should play. Defaults to "playing or buffering". Play/pause controls follow this, [status] says whether
  /// sound has actually started.
  final bool playWhenReady;
  final bool shuffleEnabled;
  final PlaybackRepeatMode repeatMode;

  /// Duration reported by the audio engine; `null` until known.
  final Duration? duration;

  /// The most recent expected failure, if any. Cleared by the next command.
  final AppFailure? failure;

  Track? get currentTrack {
    final index = currentIndex;
    return index == null ? null : queue[index];
  }

  /// Sound is actually playing (engine-confirmed).
  bool get isPlaying => status == PlaybackStatus.playing;

  /// Waiting for audio that should play: show progress, not silence.
  bool get isWaiting =>
      playWhenReady &&
      (status == PlaybackStatus.loading || status == PlaybackStatus.buffering);

  /// Whether "next" leads somewhere (at the end only when repeating).
  bool get hasNext {
    final index = currentIndex;
    if (index == null) return false;
    return index < queue.length - 1 || repeatMode != PlaybackRepeatMode.off;
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackSnapshot &&
      elementsEqual(other.queue, queue) &&
      other.currentIndex == currentIndex &&
      other.status == status &&
      other.playWhenReady == playWhenReady &&
      other.shuffleEnabled == shuffleEnabled &&
      other.repeatMode == repeatMode &&
      other.duration == duration &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(queue),
    currentIndex,
    status,
    shuffleEnabled,
    repeatMode,
    duration,
    failure,
    playWhenReady,
  );
}
