import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/simulated_audio_engine.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

import '../helpers/fakes.dart';

/// Tracks of 1, 2, 3, ... seconds, each a bundled asset.
List<Track> tracks(int count) => [
  for (var i = 0; i < count; i++)
    Track(
      id: TrackId('t$i'),
      title: 'Track $i',
      duration: Duration(seconds: i + 1),
      sources: [BundledAudioSource('a/$i.wav')],
    ),
];

const playing = AudioEngineState(phase: AudioEnginePhase.ready, playing: true);
const completed = AudioEngineState(
  phase: AudioEnginePhase.completed,
  playing: true,
);

void main() {
  // ── With the silent engine: the full playback behavior over time.
  // testWidgets provides the fake clock that drives the engine's timer.
  group('with the simulated engine', () {
    late EnginePlaybackController player;
    const tick = Duration(milliseconds: 100);

    Future<void> start({int count = 3, int startIndex = 0}) async {
      player = EnginePlaybackController(
        engine: SimulatedAudioEngine(tick: tick),
        random: Random(1),
      );
      await player.setQueue(tracks(count), startIndex: startIndex);
    }

    String? current() => player.snapshot.currentTrack?.title;

    testWidgets('starts idle and empty', (tester) async {
      player = EnginePlaybackController(engine: SimulatedAudioEngine());
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

    testWidgets('a finished track advances and keeps playing', (tester) async {
      await start();
      await player.play();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      expect(current(), 'Track 1');
      expect(player.snapshot.status, PlaybackStatus.playing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(player.position, const Duration(milliseconds: 500));
      await player.dispose();
    });

    testWidgets('the queue completes, then play starts it over', (
      tester,
    ) async {
      await start(count: 2, startIndex: 1);
      await player.play();
      await tester.pump(const Duration(seconds: 3));

      expect(player.snapshot.status, PlaybackStatus.completed);
      expect(player.position, const Duration(seconds: 2));

      await player.play();
      expect(current(), 'Track 0');
      expect(player.snapshot.status, PlaybackStatus.playing);
      await player.dispose();
    });

    testWidgets('repeat one replays the same track', (tester) async {
      await start();
      await player.setRepeatMode(PlaybackRepeatMode.one);
      await player.play();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(current(), 'Track 0');
      expect(player.position, const Duration(milliseconds: 500));
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

    testWidgets('choosing a track from the queue plays it', (tester) async {
      await start();
      await player.skipToIndex(2);
      expect(current(), 'Track 2');
      expect(player.snapshot.status, PlaybackStatus.playing);
      expect(() => player.skipToIndex(3), throwsRangeError);
      await player.dispose();
    });

    testWidgets('shuffle keeps the current track; off restores the order', (
      tester,
    ) async {
      await start(count: 10, startIndex: 4);
      await player.setShuffleEnabled(true);
      expect(current(), 'Track 4');
      expect(player.snapshot.currentIndex, 0);

      await player.setShuffleEnabled(false);
      expect(current(), 'Track 4');
      expect(player.snapshot.queue, tracks(10));
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
  });

  // ── With a scripted engine: failures, interruptions, stale events.
  group('with a scripted engine', () {
    late FakeAudioEngine engine;
    late EnginePlaybackController player;

    setUp(() {
      engine = FakeAudioEngine();
      player = EnginePlaybackController(engine: engine, random: Random(1));
    });

    tearDown(() => player.dispose());

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test(
      'an online track without its provider fails without loading',
      () async {
        final onlineOnly = Track(
          id: const TrackId('online'),
          title: 'Online',
          sources: const [
            ProviderTrackSource(
              providerId: ProviderId('p'),
              externalId: ExternalTrackId('1'),
            ),
          ],
        );
        await player.setQueue([onlineOnly]);

        expect(engine.loads, isEmpty);
        expect(player.snapshot.failure, isA<FeatureUnavailableFailure>());
        expect(player.snapshot.status, PlaybackStatus.failed);
      },
    );

    test(
      'a file that fails to load is reported; next track recovers',
      () async {
        engine.failNextLoad = const AudioLoadException('code -11828');
        await player.setQueue(tracks(2));

        final failure = player.snapshot.failure;
        expect(failure, isA<UnsupportedMediaFailure>());
        expect(failure!.debugMessage, contains('-11828'));

        await player.skipToNext();
        expect(player.snapshot.failure, isNull);
        expect(player.snapshot.currentTrack!.title, 'Track 1');
      },
    );

    test('play after a failed load retries the load', () async {
      engine.failNextLoad = const AudioLoadException('broken');
      await player.setQueue(tracks(1));
      expect(engine.loads, hasLength(1));

      await player.play();
      expect(engine.loads, hasLength(2));
      expect(player.snapshot.status, PlaybackStatus.playing);
      expect(engine.playCalls, 1);
    });

    test('rapid skips: only the last load wins', () async {
      await player.setQueue(tracks(5));
      await player.play();
      engine.holdLoads = true;

      final skips = [for (var i = 0; i < 3; i++) player.skipToNext()];
      // Resolution is asynchronous: let the surviving load reach the engine.
      await settle();
      engine.finishLoad(const Duration(seconds: 4));
      await Future.wait(skips);

      expect(player.snapshot.currentTrack!.title, 'Track 3');
      expect(player.snapshot.status, PlaybackStatus.playing);
      expect(player.snapshot.failure, isNull);
    });

    test('a completion event while loading is ignored', () async {
      await player.setQueue(tracks(3));
      await player.play();
      engine.holdLoads = true;
      final skip = player.skipToNext();

      engine.emit(completed);
      await settle();
      expect(player.snapshot.currentTrack!.title, 'Track 1');

      engine.finishLoad(const Duration(seconds: 2));
      await skip;
      expect(player.snapshot.currentTrack!.title, 'Track 1');
    });

    test('completion while playing loads and plays the next track', () async {
      await player.setQueue(tracks(3));
      await player.play();
      final playsBefore = engine.playCalls;

      engine.emit(completed);
      await settle();

      expect(player.snapshot.currentTrack!.title, 'Track 1');
      expect(engine.playCalls, playsBefore + 1);
    });

    test('completion when paused is ignored', () async {
      await player.setQueue(tracks(3));
      engine.emit(completed);
      await settle();
      expect(player.snapshot.currentTrack!.title, 'Track 0');
    });

    test('the end of the queue pauses the engine', () async {
      await player.setQueue(tracks(1));
      await player.play();
      final pausesBefore = engine.pauseCalls;

      engine.emit(completed);
      await settle();

      expect(player.snapshot.status, PlaybackStatus.completed);
      expect(engine.pauseCalls, pausesBefore + 1);
    });

    test('repeat one rewinds instead of reloading', () async {
      await player.setQueue(tracks(2));
      await player.setRepeatMode(PlaybackRepeatMode.one);
      await player.play();
      final loadsBefore = engine.loads.length;

      engine.emit(completed);
      await settle();

      expect(engine.loads, hasLength(loadsBefore));
      expect(engine.seeks.last, Duration.zero);
    });

    test('seek is clamped and ignored before anything is loaded', () async {
      await player.seek(const Duration(seconds: 5));
      expect(engine.seeks, isEmpty);

      await player.setQueue(tracks(1));
      await player.seek(const Duration(minutes: 1));
      expect(engine.seeks.last, const Duration(seconds: 1));
      await player.seek(const Duration(seconds: -3));
      expect(engine.seeks.last, Duration.zero);
    });

    test('engine positions drive the published position', () async {
      await player.setQueue(tracks(3));
      engine.moveTo(const Duration(milliseconds: 700));
      await settle();
      expect(player.position, const Duration(milliseconds: 700));
    });

    test('an empty queue is idle and pauses the engine', () async {
      await player.setQueue(tracks(2));
      await player.play();
      await player.setQueue(const []);
      expect(player.snapshot.status, PlaybackStatus.idle);
      expect(player.snapshot.currentIndex, isNull);
      expect(engine.pauseCalls, greaterThan(0));
    });

    test('dispose releases the engine and ignores later events', () async {
      await player.setQueue(tracks(2));
      await player.dispose();
      expect(engine.disposed, isTrue);
      await player.play();
      await player.skipToNext();
      expect(player.snapshot.currentTrack!.title, 'Track 0');
    });
  });

  test('playing is shown only once the engine confirms it', () async {
    final engine = FakeAudioEngine()..bufferOnPlay = true;
    final player = EnginePlaybackController(engine: engine);
    await player.setQueue(tracks(1));
    await player.play();
    // Asked to play, but the engine is still buffering.
    expect(player.snapshot.status, PlaybackStatus.buffering);
    expect(player.snapshot.playWhenReady, isTrue);
    expect(player.snapshot.isWaiting, isTrue);

    engine.emit(playing);
    expect(player.snapshot.status, PlaybackStatus.playing);

    // A stall mid-track shows as buffering again, not as silence.
    engine.emit(
      const AudioEngineState(phase: AudioEnginePhase.buffering, playing: true),
    );
    expect(player.snapshot.status, PlaybackStatus.buffering);
    await player.dispose();
  });
}
