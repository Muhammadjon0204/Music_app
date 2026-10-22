import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/system_media_session.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

import '../helpers/fakes.dart';

final _song = Track(
  id: const TrackId('song'),
  title: 'Звезда',
  artistName: 'Кино',
  albumTitle: 'Группа крови',
  duration: const Duration(minutes: 4),
  artworkUri: Uri.parse('library:artwork/cover.jpg'),
  sources: const [LocalFileSource('library:audio/song.mp3')],
);

final _untagged = Track(
  id: const TrackId('other'),
  title: 'Без тегов',
  sources: const [LocalFileSource('library:audio/other.mp3')],
);

PlaybackSnapshot _snapshot({
  PlaybackStatus status = PlaybackStatus.paused,
  int index = 0,
  bool shuffle = false,
  PlaybackRepeatMode repeat = PlaybackRepeatMode.off,
  Duration? duration,
}) => PlaybackSnapshot(
  queue: [_song, _untagged],
  currentIndex: index,
  status: status,
  playWhenReady:
      status == PlaybackStatus.playing || status == PlaybackStatus.buffering,
  shuffleEnabled: shuffle,
  repeatMode: repeat,
  duration: duration,
);

void main() {
  late FakePlaybackController controller;
  late SystemMediaSession session;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    controller = FakePlaybackController(_snapshot());
    session = SystemMediaSession(
      controller,
      artworkPath: (uri) => '/container/${uri.path}',
      now: () => now,
    );
  });

  tearDown(() async {
    await session.dispose();
    await controller.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('shows the current track with metadata and artwork', () {
    final item = session.mediaItem.value!;
    expect(item.id, 'song');
    expect(item.title, 'Звезда');
    expect(item.artist, 'Кино');
    expect(item.album, 'Группа крови');
    expect(item.duration, const Duration(minutes: 4));
    expect(item.artUri, Uri.file('/container/artwork/cover.jpg'));
  });

  test('missing tags stay empty instead of placeholders', () async {
    controller.emit(_snapshot(index: 1));
    await settle();
    final item = session.mediaItem.value!;
    expect(item.title, 'Без тегов');
    expect(item.artist, isNull);
    expect(item.artUri, isNull);
  });

  test('nothing is shown when nothing is queued', () async {
    controller.emit(PlaybackSnapshot.initial);
    await settle();
    expect(session.mediaItem.value, isNull);
    expect(
      session.playbackState.value.processingState,
      AudioProcessingState.idle,
    );
  });

  test('state follows the app: play/pause control, modes, index', () async {
    expect(session.playbackState.value.playing, isFalse);
    expect(session.playbackState.value.controls[1], MediaControl.play);

    controller.emit(
      _snapshot(
        status: PlaybackStatus.playing,
        index: 1,
        shuffle: true,
        repeat: PlaybackRepeatMode.one,
      ),
    );
    await settle();
    final state = session.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.controls, [
      MediaControl.skipToPrevious,
      MediaControl.pause,
      MediaControl.skipToNext,
    ]);
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.queueIndex, 1);
    expect(state.shuffleMode, AudioServiceShuffleMode.all);
    expect(state.repeatMode, AudioServiceRepeatMode.one);
    expect(state.systemActions, contains(MediaAction.seek));
  });

  test('lock screen and headphone commands reach the controller', () async {
    await session.play();
    await session.pause();
    await session.skipToNext();
    await session.skipToPrevious();
    await session.seek(const Duration(seconds: 42));
    await session.setShuffleMode(AudioServiceShuffleMode.all);
    await session.setRepeatMode(AudioServiceRepeatMode.all);

    expect(controller.playCalls, 1);
    expect(controller.pauseCalls, 1);
    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 1);
    expect(controller.seeks, [const Duration(seconds: 42)]);
    expect(controller.shuffleEnabled, isTrue);
    expect(controller.repeatMode, PlaybackRepeatMode.all);
  });

  test('a headphone click toggles play and pause', () async {
    await session.click();
    expect(controller.playCalls, 1);

    controller.emit(_snapshot(status: PlaybackStatus.playing));
    await settle();
    await session.click();
    expect(controller.pauseCalls, 1);
  });

  test('a system "stop" only pauses and keeps the queue', () async {
    await session.stop();
    expect(controller.pauseCalls, 1);
    expect(controller.lastQueue, isNull);
  });

  test('position is sent on jumps, not on every tick', () async {
    controller.emit(_snapshot(status: PlaybackStatus.playing));
    await settle();
    final published = session.playbackState.value;

    // Normal playback matches the system's own extrapolation.
    now = now.add(const Duration(seconds: 5));
    controller.emitPosition(const Duration(seconds: 5));
    await settle();
    expect(session.playbackState.value, same(published));

    // A seek in the app is republished with the current time.
    controller.emitPosition(const Duration(minutes: 2));
    await settle();
    expect(
      session.playbackState.value.updatePosition,
      const Duration(minutes: 2),
    );
    expect(session.playbackState.value.updateTime, now);
  });

  test('a measured duration for the same track updates the item', () async {
    controller.emit(
      _snapshot(duration: const Duration(minutes: 4, seconds: 3)),
    );
    await settle();
    expect(
      session.mediaItem.value!.duration,
      const Duration(minutes: 4, seconds: 3),
    );
  });

  test('an online cover is passed as its HTTPS URL', () async {
    final online = Track(
      id: const TrackId('audius:x'),
      title: 'Online',
      artworkUri: Uri.parse('https://node.example/480x480.jpg'),
      sources: const [
        ProviderTrackSource(
          providerId: ProviderId('audius'),
          externalId: ExternalTrackId('x'),
        ),
      ],
    );
    controller.emit(PlaybackSnapshot(queue: [online], currentIndex: 0));
    await settle();
    expect(
      session.mediaItem.value!.artUri,
      Uri.parse('https://node.example/480x480.jpg'),
    );
  });
}
