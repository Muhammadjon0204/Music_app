import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// When playback will be paused, if at all.
final class SleepTimerState {
  const SleepTimerState({this.endsAt, this.endOfTrack = false});

  static const off = SleepTimerState();

  /// Pause at this time.
  final DateTime? endsAt;

  /// Pause when the current track ends.
  final bool endOfTrack;

  bool get isActive => endsAt != null || endOfTrack;
}

/// Pauses playback after a while, or when the current track ends. Only for
/// this launch: a timer is not restored after a restart.
class SleepTimerController extends Notifier<SleepTimerState> {
  /// Choices offered to the user.
  static const presets = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(hours: 1),
  ];

  Timer? _timer;
  StreamSubscription<PlaybackSnapshot>? _snapshots;

  @override
  SleepTimerState build() {
    ref.onDispose(_stopWatching);
    return SleepTimerState.off;
  }

  /// Pauses after [duration].
  void startFor(Duration duration) {
    _stopWatching();
    final now = ref.read(clockProvider)();
    state = SleepTimerState(endsAt: now.add(duration));
    _timer = Timer(duration, _fire);
  }

  /// Pauses when the track playing now ends, i.e. as soon as another one
  /// takes its place or the queue finishes. Does nothing without a track.
  void stopAtEndOfTrack() {
    _stopWatching();
    final player = ref.read(playbackControllerProvider);
    final TrackId? current = player?.snapshot.currentTrack?.id;
    if (player == null || current == null) {
      state = SleepTimerState.off;
      return;
    }
    state = const SleepTimerState(endOfTrack: true);
    _snapshots = player.snapshots.listen((snapshot) {
      if (snapshot.currentTrack?.id != current ||
          snapshot.status == PlaybackStatus.completed) {
        _fire();
      }
    });
  }

  void cancel() {
    _stopWatching();
    state = SleepTimerState.off;
  }

  void _fire() {
    _stopWatching();
    state = SleepTimerState.off;
    unawaited(ref.read(playbackControllerProvider)?.pause());
  }

  void _stopWatching() {
    _timer?.cancel();
    _timer = null;
    unawaited(_snapshots?.cancel());
    _snapshots = null;
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
    );
