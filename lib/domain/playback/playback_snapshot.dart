import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/track.dart';

enum PlaybackStatus { idle, loading, playing, paused, completed }

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
    this.shuffleEnabled = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.duration,
    this.failure,
  }) : queue = List.unmodifiable(queue) {
    final index = currentIndex;
    if (index != null && (index < 0 || index >= this.queue.length)) {
      throw RangeError.index(index, this.queue, 'currentIndex');
    }
  }

  static final PlaybackSnapshot initial = PlaybackSnapshot(queue: const []);

  final List<Track> queue;
  final int? currentIndex;
  final PlaybackStatus status;
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

  bool get isPlaying => status == PlaybackStatus.playing;

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
  );
}
