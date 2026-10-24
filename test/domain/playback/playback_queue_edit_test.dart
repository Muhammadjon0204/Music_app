import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_queue.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

Track _t(String name) => Track(
  id: TrackId(name),
  title: name,
  sources: [LocalFileSource('/m/$name.mp3')],
);

List<String> _titles(PlaybackQueue q) =>
    q.playOrder.map((t) => t.title).toList();

void main() {
  final abcd = [_t('a'), _t('b'), _t('c'), _t('d')];

  group('play next', () {
    test('goes right after the current track', () {
      final q = PlaybackQueue(
        abcd,
        startIndex: 1,
      ).insertNext([_t('x'), _t('y')]);
      expect(_titles(q), ['a', 'b', 'x', 'y', 'c', 'd']);
      expect(q.current!.title, 'b');
    });

    test('when shuffled, too — and stays next after unshuffling', () {
      final shuffled = PlaybackQueue(abcd, startIndex: 2).shuffled(Random(3));
      final q = shuffled.insertNext([_t('x')]);
      expect(q.playOrder[q.position + 1].title, 'x');
      expect(q.current!.title, 'c');

      final plain = q.unshuffled();
      expect(_titles(plain), ['a', 'b', 'c', 'x', 'd']);
      expect(plain.current!.title, 'c');
    });

    test('into an empty queue makes it the queue', () {
      final q = PlaybackQueue.empty.insertNext([_t('x')]);
      expect(_titles(q), ['x']);
      expect(q.current!.title, 'x');
    });
  });

  group('add to the end', () {
    test('appends, keeping the current track', () {
      final q = PlaybackQueue(abcd, startIndex: 3).append([_t('x')]);
      expect(_titles(q), ['a', 'b', 'c', 'd', 'x']);
      expect(q.current!.title, 'd');
      // "Next" now leads to the added track.
      expect(
        q
            .next(PlaybackRepeatMode.off, AdvanceReason.trackCompleted)!
            .current!
            .title,
        'x',
      );
    });

    test('lands last even when shuffled', () {
      final q = PlaybackQueue(abcd).shuffled(Random(1)).append([_t('x')]);
      expect(q.playOrder.last.title, 'x');
    });
  });

  group('remove', () {
    test('a later track', () {
      final q = PlaybackQueue(abcd, startIndex: 1).removeAt(3);
      expect(_titles(q), ['a', 'b', 'c']);
      expect(q.current!.title, 'b');
    });

    test('an earlier track keeps the current one current', () {
      final q = PlaybackQueue(abcd, startIndex: 2).removeAt(0);
      expect(_titles(q), ['b', 'c', 'd']);
      expect(q.current!.title, 'c');
    });

    test('the current track cannot be removed', () {
      expect(
        () => PlaybackQueue(abcd, startIndex: 1).removeAt(1),
        throwsStateError,
      );
    });

    test('works on a shuffled queue and survives unshuffling', () {
      final shuffled = PlaybackQueue(abcd).shuffled(Random(7));
      final victim = shuffled.playOrder[2].title;
      final q = shuffled.removeAt(2);
      expect(_titles(q), isNot(contains(victim)));
      expect(_titles(q.unshuffled()), isNot(contains(victim)));
      expect(q.unshuffled().tracks, hasLength(3));
    });

    test('the same track queued twice is removed once', () {
      final q = PlaybackQueue([_t('a'), _t('b'), _t('b')]).removeAt(2);
      expect(_titles(q), ['a', 'b']);
    });
  });

  group('move', () {
    test('down, with the current track following its new place', () {
      final q = PlaybackQueue(abcd, startIndex: 1).move(0, 3);
      expect(_titles(q), ['b', 'c', 'd', 'a']);
      expect(q.current!.title, 'b');
      expect(q.position, 0);
    });

    test('up', () {
      final q = PlaybackQueue(abcd).move(3, 1);
      expect(_titles(q), ['a', 'd', 'b', 'c']);
      expect(q.current!.title, 'a');
    });

    test('the current track itself', () {
      final q = PlaybackQueue(abcd, startIndex: 1).move(1, 3);
      expect(_titles(q), ['a', 'c', 'd', 'b']);
      expect(q.current!.title, 'b');
    });

    test('unshuffled moves become the original order', () {
      final q = PlaybackQueue(abcd).move(0, 2).shuffled(Random(2)).unshuffled();
      expect(_titles(q), ['b', 'c', 'a', 'd']);
    });

    test('shuffled moves change only the play order', () {
      final shuffled = PlaybackQueue(abcd).shuffled(Random(5));
      final q = shuffled.move(1, 3);
      expect(q.tracks, shuffled.tracks);
      expect(q.playOrder[3], shuffled.playOrder[1]);
      expect(_titles(q.unshuffled()), ['a', 'b', 'c', 'd']);
    });

    test('out-of-range indexes are programming errors', () {
      expect(() => PlaybackQueue(abcd).move(0, 4), throwsRangeError);
      expect(() => PlaybackQueue(abcd).removeAt(9), throwsRangeError);
    });
  });
}
