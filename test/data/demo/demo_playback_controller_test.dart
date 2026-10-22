import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/demo/demo_playback_controller.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

const tick = Duration(milliseconds: 100);

/// Tracks of 1, 2, 3, ... seconds.
List<Track> tracks(int count) => [
  for (var i = 0; i < count; i++)
    Track(
      id: TrackId('t$i'),
      title: 'Track $i',
      duration: Duration(seconds: i + 1),
      sources: [LocalFileSource('$i')],
    ),
];

// testWidgets is used for its fake clock, which drives the demo timer.
void main() {
  late DemoPlaybackController player;

  Future<void> start({int count = 3, int startIndex = 0}) async {
    player = DemoPlaybackController(random: Random(1), tick: tick);
    await player.setQueue(tracks(count), startIndex: startIndex);
  }

  String? current() => player.snapshot.currentTrack?.title;

  testWidgets('starts idle and empty', (tester) async {
    player = DemoPlaybackController(tick: tick);
    expect(player.snapshot.status, PlaybackStatus.idle);
    expect(player.snapshot.currentTrack, isNull);
    await player.dispose();
  });

  testWidgets('a new queue is paused at its start index', (tester) async {
    await start(startIndex: 1);
    expect(player.snapshot.status, PlaybackStatus.paused);
    expect(current(), 'Track 1');
    expect(player.snapshot.duration, const Duration(seconds: 2));
    expect(player.position, Duration.zero);
    await player.dispose();
  });

  testWidgets('position advances only while playing', (tester) async {
    await start(count: 2, startIndex: 1);
    await player.play();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(player.position, const Duration(milliseconds: 1000));

    await player.pause();
    await tester.pump(const Duration(milliseconds: 500));
    expect(player.position, const Duration(milliseconds: 1000));
    await player.dispose();
  });

  testWidgets('seek is clamped to the track', (tester) async {
    await start();
    await player.seek(const Duration(seconds: -5));
    expect(player.position, Duration.zero);
    await player.seek(const Duration(minutes: 5));
    expect(player.position, const Duration(seconds: 1));
    await player.dispose();
  });

  testWidgets('a finished track advances to the next one', (tester) async {
    await start();
    await player.play();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(current(), 'Track 1');
    expect(player.position, Duration.zero);
    expect(player.snapshot.status, PlaybackStatus.playing);
    await player.dispose();
  });

  testWidgets('the queue completes, then play starts it over', (tester) async {
    await start(count: 2, startIndex: 1);
    await player.play();
    await tester.pump(const Duration(seconds: 3));

    expect(player.snapshot.status, PlaybackStatus.completed);
    expect(player.position, const Duration(seconds: 2));

    await player.play();
    expect(current(), 'Track 0');
    expect(player.position, Duration.zero);
    await player.dispose();
  });

  testWidgets('repeat one replays the same track', (tester) async {
    await start();
    await player.setRepeatMode(PlaybackRepeatMode.one);
    await player.play();
    await tester.pump(const Duration(milliseconds: 1500));

    expect(current(), 'Track 0');
    await player.dispose();
  });

  testWidgets('repeat all wraps from the last track', (tester) async {
    await start(count: 2, startIndex: 1);
    await player.setRepeatMode(PlaybackRepeatMode.all);
    await player.play();
    await tester.pump(const Duration(milliseconds: 2100));

    expect(current(), 'Track 0');
    expect(player.snapshot.status, PlaybackStatus.playing);
    await player.dispose();
  });

  testWidgets('next at the end without repeat does nothing', (tester) async {
    await start(startIndex: 2);
    await player.skipToNext();
    expect(current(), 'Track 2');
    await player.dispose();
  });

  testWidgets('previous restarts after 3 s, otherwise goes back', (
    tester,
  ) async {
    await start(count: 6, startIndex: 5);
    await player.play();
    await tester.pump(const Duration(seconds: 4));
    await player.skipToPrevious();
    expect(current(), 'Track 5');
    expect(player.position, Duration.zero);

    await player.skipToPrevious();
    expect(current(), 'Track 4');
    await player.dispose();
  });

  testWidgets('previous on the first track restarts it', (tester) async {
    await start();
    await player.seek(const Duration(milliseconds: 500));
    await player.skipToPrevious();
    expect(current(), 'Track 0');
    expect(player.position, Duration.zero);
    await player.dispose();
  });

  testWidgets('shuffle keeps the current track; off restores the order', (
    tester,
  ) async {
    await start(count: 10, startIndex: 4);
    await player.setShuffleEnabled(true);
    expect(player.snapshot.shuffleEnabled, isTrue);
    expect(current(), 'Track 4');
    expect(player.snapshot.currentIndex, 0);

    await player.setShuffleEnabled(false);
    expect(player.snapshot.shuffleEnabled, isFalse);
    expect(current(), 'Track 4');
    expect(player.snapshot.queue, tracks(10));
    await player.dispose();
  });

  testWidgets('skipToIndex jumps in play order and rejects bad indexes', (
    tester,
  ) async {
    await start();
    await player.skipToIndex(2);
    expect(current(), 'Track 2');
    expect(() => player.skipToIndex(3), throwsRangeError);
    await player.dispose();
  });

  testWidgets('an empty queue is idle', (tester) async {
    await start();
    await player.setQueue(const []);
    expect(player.snapshot.status, PlaybackStatus.idle);
    expect(player.snapshot.currentIndex, isNull);
    await player.play();
    expect(player.snapshot.status, PlaybackStatus.idle);
    await player.dispose();
  });

  testWidgets('rapid commands stay consistent', (tester) async {
    await start(count: 5);
    for (var i = 0; i < 100; i++) {
      await player.skipToNext();
    }
    expect(current(), 'Track 4');

    for (var i = 0; i < 51; i++) {
      await (player.snapshot.isPlaying ? player.pause() : player.play());
    }
    expect(player.snapshot.status, PlaybackStatus.playing);
    await player.dispose();
  });

  testWidgets('streams publish snapshots and positions', (tester) async {
    await start();
    final snapshots = <PlaybackSnapshot>[];
    final positions = <Duration>[];
    player.snapshots.listen(snapshots.add);
    player.positions.listen(positions.add);

    await player.play();
    await tester.pump(const Duration(milliseconds: 300));

    expect(snapshots.last.status, PlaybackStatus.playing);
    expect(positions, isNotEmpty);
    expect(positions.last, const Duration(milliseconds: 300));
    await player.dispose();
  });

  testWidgets('after dispose, commands are ignored and nothing ticks', (
    tester,
  ) async {
    await start();
    await player.play();
    await player.dispose();

    await player.play();
    await player.skipToNext();
    await player.seek(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(player.position, Duration.zero);
  });
}
