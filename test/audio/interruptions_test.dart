import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/audio/audio_interruptions.dart';
import 'package:music_app/audio/engine_playback_controller.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

import '../helpers/fakes.dart';

final _tracks = [
  for (var i = 0; i < 2; i++)
    Track(
      id: TrackId('t$i'),
      title: 'Track $i',
      duration: const Duration(seconds: 30),
      sources: [BundledAudioSource('a/$i.wav')],
    ),
];

void main() {
  late FakeAudioEngine engine;
  late StreamController<AudioInterruption> events;
  late EnginePlaybackController player;

  setUp(() async {
    engine = FakeAudioEngine();
    events = StreamController<AudioInterruption>.broadcast();
    player = EnginePlaybackController(
      engine: engine,
      interruptions: events.stream,
    );
    await player.setQueue(_tracks);
  });

  tearDown(() async {
    await player.dispose();
    await events.close();
  });

  Future<void> send(AudioInterruption event) async {
    events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  PlaybackStatus status() => player.snapshot.status;

  test('a call pauses, and playback resumes when the system allows', () async {
    await player.play();
    await send(AudioInterruption.began);
    expect(status(), PlaybackStatus.paused);

    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.playing);
    expect(engine.playCalls, 2);
  });

  test('no resume when the system says not to', () async {
    await player.play();
    await send(AudioInterruption.began);
    await send(AudioInterruption.endedNoResume);
    expect(status(), PlaybackStatus.paused);

    // A later "may resume" from another interruption does not apply.
    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.paused);
  });

  test('music that was paused stays paused after an interruption', () async {
    await send(AudioInterruption.began);
    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.paused);
    expect(engine.playCalls, 0);
  });

  test('the user taking over during a call cancels the resume', () async {
    await player.play();
    await send(AudioInterruption.began);
    // The user presses play, then pause, on the lock screen meanwhile.
    await player.play();
    await player.pause();
    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.paused);
  });

  test('choosing another queue during a call cancels the resume', () async {
    await player.play();
    await send(AudioInterruption.began);
    await player.setQueue(_tracks.reversed.toList());
    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.paused);
  });

  test('unplugged headphones pause and never resume by themselves', () async {
    await player.play();
    await send(AudioInterruption.becameNoisy);
    expect(status(), PlaybackStatus.paused);

    await send(AudioInterruption.endedMayResume);
    expect(status(), PlaybackStatus.paused);
  });

  test('ducking lowers and restores the volume without pausing', () async {
    await player.play();
    await send(AudioInterruption.beganDuck);
    expect(engine.volumes, [EnginePlaybackController.duckedVolume]);
    expect(status(), PlaybackStatus.playing);

    await send(AudioInterruption.endedDuck);
    expect(engine.volumes.last, 1);
  });

  test('the queue position is kept across an interruption', () async {
    await player.skipToNext();
    await player.play();
    await send(AudioInterruption.began);
    await send(AudioInterruption.endedMayResume);
    expect(player.snapshot.currentTrack!.title, 'Track 1');
  });

  test('events after dispose are ignored', () async {
    await player.play();
    await player.dispose();
    final pauses = engine.pauseCalls;
    events.add(AudioInterruption.began);
    await Future<void>.delayed(Duration.zero);
    expect(engine.pauseCalls, pauses);
    expect(engine.volumes, isEmpty);
  });
}
