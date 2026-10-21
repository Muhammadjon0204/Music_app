import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

Track _track(String id) => Track(
  id: TrackId(id),
  title: 'Track $id',
  sources: [LocalFileSource('$id.mp3')],
);

void main() {
  group('PlaybackSnapshot', () {
    test('initial state is idle with an empty queue', () {
      final s = PlaybackSnapshot.initial;
      expect(s.status, PlaybackStatus.idle);
      expect(s.queue, isEmpty);
      expect(s.currentTrack, isNull);
    });

    test('currentTrack follows currentIndex', () {
      final s = PlaybackSnapshot(
        queue: [_track('1'), _track('2')],
        currentIndex: 1,
      );
      expect(s.currentTrack?.id, const TrackId('2'));
    });

    test('rejects an out-of-range index', () {
      expect(
        () => PlaybackSnapshot(queue: [_track('1')], currentIndex: 1),
        throwsRangeError,
      );
      expect(
        () => PlaybackSnapshot(queue: const [], currentIndex: 0),
        throwsRangeError,
      );
    });

    test('value equality, so Riverpod skips redundant notifications', () {
      PlaybackSnapshot build() => PlaybackSnapshot(
        queue: [_track('1')],
        currentIndex: 0,
        status: PlaybackStatus.playing,
      );

      expect(build(), build());
      expect(
        build(),
        isNot(
          PlaybackSnapshot(
            queue: [_track('1')],
            currentIndex: 0,
            status: PlaybackStatus.paused,
          ),
        ),
      );
    });
  });
}
