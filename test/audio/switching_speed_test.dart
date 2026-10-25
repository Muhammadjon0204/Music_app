import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
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

void main() {
  late FakeAudioEngine engine;
  late EnginePlaybackController player;

  /// Tracks asked for, in order (playing and prefetching alike).
  late List<String> resolved;

  /// Tracks whose lookup waits until completed by the test.
  late Map<String, Completer<void>> slow;

  setUp(() {
    engine = FakeAudioEngine();
    resolved = [];
    slow = {};
    player = EnginePlaybackController(
      engine: engine,
      resolver: (Track track, Cancellation _) async {
        resolved.add(track.title);
        await slow[track.title]?.future;
        return Ok(FileAudio('/m/${track.title}.mp3'));
      },
    );
  });

  tearDown(() => player.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'the old track falls silent at once while the new one is looked up',
    () async {
      await player.setQueue([_t('a'), _t('b')], play: true);
      await settle();
      expect(engine.isPlaying, isTrue);

      slow['x'] = Completer<void>();
      unawaited(player.setQueue([_t('x')], play: true));
      await settle();
      // Still looking up "x", and "a" is no longer heard.
      expect(player.snapshot.status, PlaybackStatus.loading);
      expect(engine.isPlaying, isFalse);

      slow['x']!.complete();
      await settle();
      await settle();
      expect(player.snapshot.currentTrack?.title, 'x');
      expect(engine.isPlaying, isTrue);
      expect((engine.loads.last as FileAudio).path, '/m/x.mp3');
    },
  );

  test('the next track is looked up while the current one plays', () async {
    await player.setQueue([_t('a'), _t('b'), _t('c')], play: true);
    await settle();
    expect(resolved, ['a', 'b']);

    await player.skipToNext();
    await settle();
    expect(resolved, ['a', 'b', 'b', 'c']);
  });

  test('nothing is prefetched at the end of the queue', () async {
    await player.setQueue([_t('a')], play: true);
    await settle();
    expect(resolved, ['a']);
  });

  test('a rapid second choice wins over a slow first one', () async {
    slow['a'] = Completer<void>();
    unawaited(player.setQueue([_t('a')], play: true));
    await settle();
    await player.setQueue([_t('b')], play: true);
    await settle();
    slow['a']!.complete();
    await settle();
    await settle();
    expect(player.snapshot.currentTrack?.title, 'b');
    expect(engine.loads.map((l) => (l as FileAudio).path), ['/m/b.mp3']);
  });
}
