import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';
import '../helpers/fakes.dart';

Track _online(String id) => Track(
  id: TrackId('fake:$id'),
  title: 'Online $id',
  duration: const Duration(minutes: 3),
  sources: [
    ProviderTrackSource(
      providerId: const ProviderId('fake'),
      externalId: ExternalTrackId(id),
      availability: StreamAvailability.full,
    ),
  ],
);

final _local = Track(
  id: const TrackId('local-1'),
  title: 'Local',
  duration: const Duration(minutes: 2),
  sources: const [LocalFileSource('/music/a.mp3')],
);

const _ready = AudioEngineState(phase: AudioEnginePhase.ready, playing: true);

void main() {
  late FakeAudioEngine engine;
  late FakeStreamingProvider provider;
  late EnginePlaybackController player;

  setUp(() {
    engine = FakeAudioEngine();
    provider = FakeStreamingProvider(
      (id) async => Ok(Uri.parse('https://api.test/v1/tracks/${id.value}')),
    );
    player = EnginePlaybackController(
      engine: engine,
      resolver: TrackAudioResolver(providers: ProviderRegistry([provider]))
          .call,
    );
  });

  tearDown(() => player.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);
  PlaybackStatus status() => player.snapshot.status;

  group('states follow the engine', () {
    test('loading while the stream is resolved', () async {
      final answer = Completer<Result<Uri>>();
      provider.respond = (_) => answer.future;
      final setting = player.setQueue([_online('a')]);
      await settle();
      expect(status(), PlaybackStatus.loading);

      answer.complete(Ok(Uri.parse('https://api.test/v1/tracks/a')));
      await setting;
      expect(status(), PlaybackStatus.paused);
      expect(engine.loads.single, isA<StreamAudio>());
    });

    test('buffering until the engine really plays', () async {
      engine.bufferOnPlay = true;
      await player.setQueue([_online('a')]);
      await player.play();
      expect(status(), PlaybackStatus.buffering);
      expect(player.snapshot.isWaiting, isTrue);

      engine.emit(_ready);
      expect(status(), PlaybackStatus.playing);
      expect(player.snapshot.isWaiting, isFalse);
    });

    test('a stall mid-track is buffering, then playing again', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      expect(status(), PlaybackStatus.playing);

      engine.emit(
        const AudioEngineState(
          phase: AudioEnginePhase.buffering,
          playing: true,
        ),
      );
      expect(status(), PlaybackStatus.buffering);
      engine.emit(_ready);
      expect(status(), PlaybackStatus.playing);
    });

    test('pause is shown as paused, with the intent cleared', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      await player.pause();
      expect(status(), PlaybackStatus.paused);
      expect(player.snapshot.playWhenReady, isFalse);
    });

    test('local tracks still play exactly as before', () async {
      await player.setQueue([_local]);
      await player.play();
      expect(engine.loads.single, isA<FileAudio>());
      expect(status(), PlaybackStatus.playing);
      expect(provider.requested, isEmpty);
    });

    test('identical engine events do not republish the state', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      final published = <PlaybackSnapshot>[];
      final sub = player.snapshots.listen(published.add);
      engine
        ..emit(_ready)
        ..emit(_ready)
        ..emit(_ready);
      await settle();
      expect(published, isEmpty);
      await sub.cancel();
    });
  });

  group('errors', () {
    test('an error mid-stream stops playback and is reported', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      engine.failPlayback(AudioErrorKind.networkUnavailable);

      expect(status(), PlaybackStatus.failed);
      expect(player.snapshot.failure, isA<NetworkFailure>());
      expect(player.snapshot.playWhenReady, isFalse);
      expect(engine.isPlaying, isFalse);
    });

    test('no automatic retry after a failure', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      engine.failPlayback(AudioErrorKind.server);
      await settle();
      await settle();
      expect(engine.loads, hasLength(1));
      expect(provider.requested, hasLength(1));
    });

    test('play retries once and continues where it stopped', () async {
      await player.setQueue([_online('a')]);
      await player.play();
      engine.moveTo(const Duration(seconds: 95));
      await settle();
      engine.failPlayback(AudioErrorKind.timeout);
      expect(player.snapshot.failure, isA<TimeoutFailure>());

      await player.play();
      // The stream URL is resolved again (it may have expired).
      expect(provider.requested, hasLength(2));
      expect(engine.loads, hasLength(2));
      expect(engine.seeks.last, const Duration(seconds: 95));
      expect(status(), PlaybackStatus.playing);
      expect(player.snapshot.failure, isNull);
    });

    test('next after a failure moves on from the start', () async {
      await player.setQueue([_online('a'), _online('b')]);
      await player.play();
      engine.moveTo(const Duration(seconds: 40));
      await settle();
      engine.failPlayback(AudioErrorKind.unknown);
      expect(player.snapshot.failure, isA<PlaybackFailure>());

      await player.skipToNext();
      await player.play();
      expect(player.snapshot.currentTrack!.title, 'Online b');
      expect(engine.seeks, isEmpty);
    });

    test('load errors are typed by what the engine reported', () async {
      engine.failNextLoad = const AudioLoadException(
        '404',
        kind: AudioErrorKind.notFound,
      );
      await player.setQueue([_online('a')]);
      expect(player.snapshot.failure, isA<NotFoundFailure>());
      expect(status(), PlaybackStatus.failed);
    });

    test('an unknown load error is not guessed', () async {
      engine.failNextLoad = const AudioLoadException('?');
      await player.setQueue([_online('a')]);
      expect(player.snapshot.failure, isA<PlaybackFailure>());

      // Local files keep the old meaning: the file cannot be decoded.
      engine.failNextLoad = const AudioLoadException('?');
      await player.setQueue([_local]);
      expect(player.snapshot.failure, isA<UnsupportedMediaFailure>());
    });

    test('a resolution failure never shows endless loading', () async {
      provider.respond = (_) async => const Err(RateLimitedFailure());
      await player.setQueue([_online('a')]);
      await player.play();
      expect(status(), PlaybackStatus.failed);
      expect(player.snapshot.failure, isA<RateLimitedFailure>());
      expect(engine.loads, isEmpty);
    });
  });

  group('races', () {
    test('a slow resolve for an old track is cancelled and ignored', () async {
      final slow = Completer<Result<Uri>>();
      provider.respond = (id) => id.value == 'a'
          ? slow.future
          : Future.value(Ok(Uri.parse('https://api.test/v1/tracks/b')));

      final first = player.setQueue([_online('a'), _online('b')]);
      await settle();
      final skip = player.skipToNext();
      await skip;
      expect(provider.cancellations.first!.isCancelled, isTrue);

      slow.complete(Ok(Uri.parse('https://api.test/v1/tracks/a')));
      await first;
      expect(player.snapshot.currentTrack!.title, 'Online b');
      expect(engine.loads, hasLength(1));
      expect((engine.loads.single as StreamAudio).uri.path, '/v1/tracks/b');
    });

    test('an error from the old track does not fail the new one', () async {
      await player.setQueue([_online('a'), _online('b')]);
      await player.play();
      engine.holdLoads = true;
      final skip = player.skipToNext();
      await settle();
      // Arrives while the next track is loading.
      engine.failPlayback(AudioErrorKind.networkUnavailable);
      engine.finishLoad(const Duration(minutes: 3));
      await skip;
      expect(player.snapshot.failure, isNull);
      expect(player.snapshot.currentTrack!.title, 'Online b');
    });

    test('pause during a load is respected when it finishes', () async {
      engine.holdLoads = true;
      final setting = player.setQueue([_online('a')]);
      await player.play();
      await player.pause();
      await settle();
      engine.finishLoad(const Duration(minutes: 3));
      await setting;
      expect(status(), PlaybackStatus.paused);
      expect(engine.isPlaying, isFalse);
    });
  });

  test('one subscription per engine stream, released on dispose', () async {
    expect(engine.hasListeners, isTrue);
    await player.dispose();
    await settle();
    expect(engine.hasListeners, isFalse);
  });
}
