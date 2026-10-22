import 'dart:math';

import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Why the player moves on. Repeat-one only holds a track when it finishes
/// by itself; an explicit skip still moves on, as on iOS.
enum AdvanceReason { trackCompleted, userSkipped }

/// "Previous" restarts the current track once it has played this long,
/// otherwise it goes to the previous track (iOS behavior).
const previousRestartThreshold = Duration(seconds: 3);

/// Immutable play queue, independent of any audio plugin.
///
/// Keeps the tracks in their original order and a separate play order, so
/// shuffle can be turned off again without losing the original sequence.
final class PlaybackQueue {
  factory PlaybackQueue(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isNotEmpty) RangeError.checkValidIndex(startIndex, tracks);
    return PlaybackQueue._(
      List.unmodifiable(tracks),
      List.unmodifiable([for (var i = 0; i < tracks.length; i++) i]),
      tracks.isEmpty ? 0 : startIndex,
      isShuffled: false,
    );
  }

  const PlaybackQueue._(
    this.tracks,
    this.order,
    this.position, {
    required this.isShuffled,
  });

  static final PlaybackQueue empty = PlaybackQueue(const []);

  /// Tracks in their original order.
  final List<Track> tracks;

  /// Play order, as indexes into [tracks].
  final List<int> order;

  /// Position of the current track within [order].
  final int position;

  final bool isShuffled;

  bool get isEmpty => tracks.isEmpty;

  Track? get current => isEmpty ? null : tracks[order[position]];

  /// Tracks in the order they will play.
  List<Track> get playOrder => [for (final i in order) tracks[i]];

  /// Shuffles everything except the current track, which moves to the front
  /// and keeps playing.
  PlaybackQueue shuffled(Random random) {
    if (isEmpty) return this;
    final currentIndex = order[position];
    final rest = [
      for (var i = 0; i < tracks.length; i++)
        if (i != currentIndex) i,
    ]..shuffle(random);
    return PlaybackQueue._(
      tracks,
      List.unmodifiable([currentIndex, ...rest]),
      0,
      isShuffled: true,
    );
  }

  /// Restores the original order, keeping the current track current.
  PlaybackQueue unshuffled() {
    if (isEmpty || !isShuffled) return this;
    return PlaybackQueue(tracks, startIndex: order[position]);
  }

  /// The queue after moving forward, or null when playback should end.
  /// At the end of the queue any repeat mode wraps to the start.
  PlaybackQueue? next(PlaybackRepeatMode repeat, AdvanceReason reason) {
    if (isEmpty) return null;
    if (repeat == PlaybackRepeatMode.one &&
        reason == AdvanceReason.trackCompleted) {
      return this;
    }
    if (position < order.length - 1) return _at(position + 1);
    return repeat == PlaybackRepeatMode.off ? null : _at(0);
  }

  /// The previous track, or null at the start unless the queue repeats.
  PlaybackQueue? previous(PlaybackRepeatMode repeat) {
    if (isEmpty) return null;
    if (position > 0) return _at(position - 1);
    return repeat == PlaybackRepeatMode.all ? _at(order.length - 1) : null;
  }

  /// Jumps to [playPosition] in the play order.
  PlaybackQueue jumpTo(int playPosition) {
    RangeError.checkValidIndex(playPosition, order, 'playPosition');
    return _at(playPosition);
  }

  PlaybackQueue _at(int newPosition) =>
      PlaybackQueue._(tracks, order, newPosition, isShuffled: isShuffled);

  @override
  bool operator ==(Object other) =>
      other is PlaybackQueue &&
      elementsEqual(other.tracks, tracks) &&
      elementsEqual(other.order, order) &&
      other.position == position &&
      other.isShuffled == isShuffled;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(tracks),
    Object.hashAll(order),
    position,
    isShuffled,
  );
}
