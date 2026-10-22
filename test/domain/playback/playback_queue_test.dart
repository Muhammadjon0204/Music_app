import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_queue.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

List<Track> tracks(int count) => [
  for (var i = 0; i < count; i++)
    Track(
      id: TrackId('t$i'),
      title: 'Track $i',
      sources: [LocalFileSource('$i.mp3')],
    ),
];

String? titleOf(PlaybackQueue? q) => q?.current?.title;

const off = PlaybackRepeatMode.off;
const all = PlaybackRepeatMode.all;
const one = PlaybackRepeatMode.one;
const completed = AdvanceReason.trackCompleted;
const skipped = AdvanceReason.userSkipped;

void main() {
  group('construction', () {
    test('starts at the given index in original order', () {
      final q = PlaybackQueue(tracks(3), startIndex: 1);
      expect(titleOf(q), 'Track 1');
      expect(q.playOrder, tracks(3));
      expect(q.isShuffled, isFalse);
    });

    test('rejects an out-of-range start', () {
      expect(() => PlaybackQueue(tracks(3), startIndex: 3), throwsRangeError);
      expect(() => PlaybackQueue(tracks(3), startIndex: -1), throwsRangeError);
    });

    test('empty queue has no current track and goes nowhere', () {
      final q = PlaybackQueue.empty;
      expect(q.current, isNull);
      expect(q.next(all, skipped), isNull);
      expect(q.previous(all), isNull);
      expect(q.shuffled(Random(1)), same(q));
    });
  });

  group('next', () {
    test('moves forward through the queue', () {
      final q = PlaybackQueue(tracks(3));
      expect(titleOf(q.next(off, completed)), 'Track 1');
      expect(titleOf(q.next(off, skipped)), 'Track 1');
    });

    test('ends after the last track when not repeating', () {
      final q = PlaybackQueue(tracks(3), startIndex: 2);
      expect(q.next(off, completed), isNull);
      expect(q.next(off, skipped), isNull);
    });

    test('repeat all wraps to the first track', () {
      final q = PlaybackQueue(tracks(3), startIndex: 2);
      expect(titleOf(q.next(all, completed)), 'Track 0');
    });

    test('repeat one replays when a track finishes by itself', () {
      final q = PlaybackQueue(tracks(3), startIndex: 1);
      expect(q.next(one, completed), q);
    });

    test('repeat one still moves on when the user skips', () {
      final q = PlaybackQueue(tracks(3), startIndex: 1);
      expect(titleOf(q.next(one, skipped)), 'Track 2');
      final last = PlaybackQueue(tracks(3), startIndex: 2);
      expect(titleOf(last.next(one, skipped)), 'Track 0');
    });

    test('a single-track queue repeats only when asked', () {
      final q = PlaybackQueue(tracks(1));
      expect(q.next(off, completed), isNull);
      expect(titleOf(q.next(all, completed)), 'Track 0');
    });
  });

  group('previous', () {
    test('goes back one track', () {
      final q = PlaybackQueue(tracks(3), startIndex: 2);
      expect(titleOf(q.previous(off)), 'Track 1');
    });

    test('at the start: nothing unless the queue repeats', () {
      final q = PlaybackQueue(tracks(3));
      expect(q.previous(off), isNull);
      expect(q.previous(one), isNull);
      expect(titleOf(q.previous(all)), 'Track 2');
    });
  });

  group('shuffle', () {
    test('keeps the current track first and current', () {
      final q = PlaybackQueue(tracks(10), startIndex: 4).shuffled(Random(7));
      expect(titleOf(q), 'Track 4');
      expect(q.position, 0);
      expect(q.playOrder.first.title, 'Track 4');
      expect(q.isShuffled, isTrue);
    });

    test('is a permutation of every track', () {
      final q = PlaybackQueue(tracks(25), startIndex: 3).shuffled(Random(1));
      expect(q.order.toSet(), {for (var i = 0; i < 25; i++) i});
      expect(q.order, hasLength(25));
    });

    test('is deterministic for a given random source', () {
      final a = PlaybackQueue(tracks(10)).shuffled(Random(42));
      final b = PlaybackQueue(tracks(10)).shuffled(Random(42));
      expect(a, b);
    });

    test('plays every track exactly once before ending', () {
      var q = PlaybackQueue(tracks(8), startIndex: 5).shuffled(Random(3));
      final played = <String>[titleOf(q)!];
      while (true) {
        final next = q.next(off, completed);
        if (next == null) break;
        q = next;
        played.add(titleOf(q)!);
      }
      expect(played, hasLength(8));
      expect(played.toSet(), hasLength(8));
    });

    test('turning shuffle off restores order and keeps the current track', () {
      final shuffled = PlaybackQueue(tracks(6)).shuffled(Random(2));
      final moved = shuffled.jumpTo(3);
      final restored = moved.unshuffled();

      expect(restored.isShuffled, isFalse);
      expect(restored.playOrder, tracks(6));
      expect(titleOf(restored), titleOf(moved));
    });

    test('unshuffling an unshuffled queue changes nothing', () {
      final q = PlaybackQueue(tracks(3), startIndex: 1);
      expect(q.unshuffled(), same(q));
    });
  });

  group('jumpTo', () {
    test('selects a position in play order', () {
      final q = PlaybackQueue(tracks(4)).jumpTo(3);
      expect(titleOf(q), 'Track 3');
    });

    test('rejects an invalid position', () {
      final q = PlaybackQueue(tracks(4));
      expect(() => q.jumpTo(4), throwsRangeError);
      expect(() => q.jumpTo(-1), throwsRangeError);
    });
  });

  test('value equality', () {
    expect(PlaybackQueue(tracks(3)), PlaybackQueue(tracks(3)));
    expect(
      PlaybackQueue(tracks(3)),
      isNot(PlaybackQueue(tracks(3), startIndex: 1)),
    );
  });

  group('PlaybackSnapshot.hasNext', () {
    PlaybackSnapshot at(int index, PlaybackRepeatMode mode) => PlaybackSnapshot(
      queue: tracks(3),
      currentIndex: index,
      repeatMode: mode,
    );

    test(
      'true before the last track',
      () => expect(at(1, off).hasNext, isTrue),
    );
    test('false on the last track without repeat', () {
      expect(at(2, off).hasNext, isFalse);
    });
    test('true on the last track when repeating', () {
      expect(at(2, all).hasNext, isTrue);
      expect(at(2, one).hasNext, isTrue);
    });
    test('false with nothing loaded', () {
      expect(PlaybackSnapshot.initial.hasNext, isFalse);
    });
  });
}
