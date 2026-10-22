import 'dart:async';

import 'package:audio_session/audio_session.dart';

/// Something outside the app affecting playback.
enum AudioInterruption {
  /// A call, alarm or another app took the audio: pause.
  began,

  /// Another app needs the audio briefly (Android navigation prompts):
  /// lower the volume.
  beganDuck,

  /// The interruption ended and the system allows resuming.
  endedMayResume,

  /// The interruption ended, but playback must not resume by itself.
  endedNoResume,

  /// The ducking interruption ended: restore the volume.
  endedDuck,

  /// Headphones or AirPods were disconnected: pause so the music does not
  /// suddenly play from the speaker.
  becameNoisy,
}

/// The audio session's interruption and "becoming noisy" events as one
/// stream.
Stream<AudioInterruption> audioSessionInterruptions(AudioSession session) {
  late final StreamController<AudioInterruption> controller;
  final subscriptions = <StreamSubscription<Object?>>[];
  controller = StreamController<AudioInterruption>.broadcast(
    onListen: () {
      subscriptions
        ..add(
          session.interruptionEventStream.listen(
            (event) => controller.add(switch ((event.begin, event.type)) {
              (true, AudioInterruptionType.duck) => AudioInterruption.beganDuck,
              (true, _) => AudioInterruption.began,
              (false, AudioInterruptionType.duck) =>
                AudioInterruption.endedDuck,
              (false, AudioInterruptionType.pause) =>
                AudioInterruption.endedMayResume,
              (false, AudioInterruptionType.unknown) =>
                AudioInterruption.endedNoResume,
            }),
          ),
        )
        ..add(
          session.becomingNoisyEventStream.listen(
            (_) => controller.add(AudioInterruption.becameNoisy),
          ),
        );
    },
    onCancel: () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      subscriptions.clear();
    },
  );
  return controller.stream;
}
