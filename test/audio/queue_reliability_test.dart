import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

import '../helpers/fakes.dart';

Track _t(String name) => Track(
  id: TrackId(name),
  title: name,
  duration: const Duration(minutes: 3),
  sources: [LocalFileSource('/m/$name.mp3')],
);

const _completed = AudioEngineState(
  phase: AudioEnginePhase.completed,
  playing: true,
);

void main() {
  late FakeAudioEngine engine;
  late EnginePlaybackController player;

  /// Track titles whose resolution fails, and how.
  late Map<String, AppFailure> broken;

  setUp(() {
    engine = FakeAudioEngine();
    broken = {};
    player = EnginePlaybackController(
      engine: engine,
      resolver: (Track track, Cancellation _) async {
        final failure = broken[track.title];
        return failure == null
            ? Ok(FileAudio('/m/${track.title}.mp3'))
            : Err(failure);
      },
    );
  });

  tearDown(() => player.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);
  String? current() => player.snapshot.currentTrack?.title;
  List<String> queue() => player.snapshot.queue.map((t) => t.title).toList();

  group('starting a new queue', () {
    test('with play: true it never shows a paused moment', () async {
      final seen = <PlaybackSnapshot>[];
      final sub = player.snapshots.listen(seen.add);
      await player.setQueue([_t('a'), _t('b')], startIndex: 1, play: true);
      await settle();

      expect(seen.every((s) => s.playWhenReady), isTrue);
      expect(seen.map((s) => s.status), isNot(contains(PlaybackStatus.paused)));
      expect(player.snapshot.status, PlaybackStatus.playing);
      expect(current(), 'b');
      await sub.cancel();
    });

    test('without play it is ready but paused', () async {
      await player.setQueue([_t('a')]);
      expect(player.snapshot.status, PlaybackStatus.paused);
      expect(engine.playCalls, 0);
    });
  });

  group('editing the queue', () {
    test(
      'play next and add to end never interrupt the current track',
      () async {
        await player.setQueue([_t('a'), _t('b')], play: true);
        final loads = engine.loads.length;

        await player.playNext([_t('x')]);
        await player.addToQueue([_t('z')]);

        expect(queue(), ['a', 'x', 'b', 'z']);
        expect(current(), 'a');
        expect(engine.loads, hasLength(loads));
        expect(player.snapshot.status, PlaybackStatus.playing);
      },
    );

    test('the queued track plays next', () async {
      await player.setQueue([_t('a'), _t('b')], play: true);
      await player.playNext([_t('x')]);
      engine.emit(_completed);
      await settle();
      expect(current(), 'x');
    });

    test('adding to an empty queue loads it, paused', () async {
      await player.addToQueue([_t('a')]);
      expect(current(), 'a');
      expect(player.snapshot.status, PlaybackStatus.paused);
      expect(engine.loads, hasLength(1));
    });

    test('remove and move keep the current track playing', () async {
      await player.setQueue([_t('a'), _t('b'), _t('c'), _t('d')], play: true);
      await player.removeFromQueue(2);
      expect(queue(), ['a', 'b', 'd']);

      await player.moveInQueue(2, 1);
      expect(queue(), ['a', 'd', 'b']);
      expect(current(), 'a');
      expect(engine.loads, hasLength(1));
    });

    test('removing the current track is ignored', () async {
      await player.setQueue([_t('a'), _t('b')], play: true);
      await player.removeFromQueue(0);
      expect(queue(), ['a', 'b']);
      expect(player.snapshot.status, PlaybackStatus.playing);
    });
  });

  group('tracks that cannot play', () {
    test('are skipped when the queue moves on by itself', () async {
      broken['b'] = const NotFoundFailure();
      broken['c'] = const AccessDeniedFailure();
      await player.setQueue([_t('a'), _t('b'), _t('c'), _t('d')], play: true);

      engine.emit(_completed);
      await settle();
      await settle();
      expect(current(), 'd');
      expect(player.snapshot.status, PlaybackStatus.playing);
      expect(player.snapshot.failure, isNull);
    });

    test('a connection problem stops instead of emptying the queue', () async {
      broken['b'] = const NetworkFailure();
      await player.setQueue([_t('a'), _t('b'), _t('c')], play: true);
      engine.emit(_completed);
      await settle();
      expect(current(), 'b');
      expect(player.snapshot.status, PlaybackStatus.failed);
      expect(player.snapshot.failure, isA<NetworkFailure>());
    });

    test('skipping is bounded', () async {
      final tracks = [for (var i = 0; i < 10; i++) _t('t$i')];
      for (final t in tracks.skip(1)) {
        broken[t.title] = const NotFoundFailure();
      }
      await player.setQueue(tracks, play: true);
      engine.emit(_completed);
      for (var i = 0; i < 10; i++) {
        await settle();
      }
      // t1 failed, then at most maxAutoSkips more were tried.
      expect(current(), 't${1 + EnginePlaybackController.maxAutoSkips}');
      expect(player.snapshot.status, PlaybackStatus.failed);
    });

    test('a track the user picked is reported, not skipped', () async {
      broken['b'] = const NotFoundFailure();
      await player.setQueue([_t('a'), _t('b'), _t('c')]);
      await player.skipToIndex(1);
      expect(current(), 'b');
      expect(player.snapshot.status, PlaybackStatus.failed);
    });

    test('the end of the queue is not passed while skipping', () async {
      broken['b'] = const NotFoundFailure();
      await player.setQueue([_t('a'), _t('b')], play: true);
      engine.emit(_completed);
      await settle();
      expect(current(), 'b');
      expect(player.snapshot.status, PlaybackStatus.failed);
    });
  });

  test('a seek while the track is loading is applied once it opens', () async {
    engine.holdLoads = true;
    final loading = player.setQueue([_t('a')], play: true);
    await settle();
    await player.seek(const Duration(seconds: 42));
    expect(player.position, const Duration(seconds: 42));

    engine.finishLoad(const Duration(minutes: 3));
    await loading;
    expect(engine.seeks.last, const Duration(seconds: 42));
  });
}
