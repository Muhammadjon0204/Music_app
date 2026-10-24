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

  /// Puts [items] right after the current track ("Play Next"). In the
  /// original order they also follow the current track, so turning shuffle
  /// off keeps them next.
  PlaybackQueue insertNext(List<Track> items) {
    if (items.isEmpty) return this;
    if (isEmpty) return PlaybackQueue(items);
    final after = order[position] + 1;
    final k = items.length;
    final shifted = [for (final i in order) i >= after ? i + k : i];
    return PlaybackQueue._(
      List.unmodifiable([
        ...tracks.sublist(0, after),
        ...items,
        ...tracks.sublist(after),
      ]),
      List.unmodifiable([
        ...shifted.sublist(0, position + 1),
        for (var j = 0; j < k; j++) after + j,
        ...shifted.sublist(position + 1),
      ]),
      position,
      isShuffled: isShuffled,
    );
  }

  /// Adds [items] at the end ("Play Last"), also when shuffled.
  PlaybackQueue append(List<Track> items) {
    if (items.isEmpty) return this;
    if (isEmpty) return PlaybackQueue(items);
    final start = tracks.length;
    return PlaybackQueue._(
      List.unmodifiable([...tracks, ...items]),
      List.unmodifiable([
        ...order,
        for (var j = 0; j < items.length; j++) start + j,
      ]),
      position,
      isShuffled: isShuffled,
    );
  }

  /// Removes the track at [playPosition]. The current track cannot be
  /// removed here (the player must move off it first).
  PlaybackQueue removeAt(int playPosition) {
    RangeError.checkValidIndex(playPosition, order, 'playPosition');
    if (playPosition == position) {
      throw StateError('The current track cannot be removed');
    }
    final removed = order[playPosition];
    return PlaybackQueue._(
      List.unmodifiable([...tracks]..removeAt(removed)),
      List.unmodifiable([
        for (var p = 0; p < order.length; p++)
          if (p != playPosition) order[p] > removed ? order[p] - 1 : order[p],
      ]),
      playPosition < position ? position - 1 : position,
      isShuffled: isShuffled,
    );
  }

  /// Moves the track at play position [from] to [to]; the current track
  /// stays current wherever it ends up. Unshuffled, the original order
  /// changes too, so the new order survives shuffle on/off.
  PlaybackQueue move(int from, int to) {
    RangeError.checkValidIndex(from, order, 'from');
    RangeError.checkValidIndex(to, order, 'to');
    if (from == to) return this;
    int follow(int p) {
      if (p == from) return to;
      if (from < p && p <= to) return p - 1;
      if (to <= p && p < from) return p + 1;
      return p;
    }

    final newPosition = follow(position);
    if (!isShuffled) {
      final reordered = [...tracks];
      reordered.insert(to, reordered.removeAt(from));
      return PlaybackQueue._(
        List.unmodifiable(reordered),
        order,
        newPosition,
        isShuffled: false,
      );
    }
    final reordered = [...order];
    reordered.insert(to, reordered.removeAt(from));
    return PlaybackQueue._(
      tracks,
      List.unmodifiable(reordered),
      newPosition,
      isShuffled: true,
    );
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
