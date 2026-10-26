import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_artist_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// A radio that is playing: started from [seed].
final class RadioState {
  const RadioState({required this.seed});

  final Track seed;
}

/// "Radio" from a track: the track, then tracks like it from its catalog;
/// when only a few are left, more are added, so the music does not stop.
/// It ends when the queue no longer holds the seed (the user played
/// something else).
class RadioController extends Notifier<RadioState?> {
  /// Tracks asked for when the radio starts, and on each refill.
  static const startCount = 30;
  static const refillCount = 20;

  /// A refill starts when this many tracks or fewer are left after the
  /// current one.
  static const refillAt = 3;

  StreamSubscription<PlaybackSnapshot>? _snapshots;
  bool _refilling = false;

  @override
  RadioState? build() {
    ref.onDispose(_stopListening);
    return null;
  }

  /// Starts the radio. Playback is untouched when nothing like [seed] is
  /// found or the catalog fails; the failure is returned to be shown.
  Future<Result<void>> start(Track seed) async {
    final player = ref.read(playbackControllerProvider);
    if (player == null) {
      return const Err(
        FeatureUnavailableFailure(debugMessage: 'No player for radio'),
      );
    }
    final result = await radioTracksFor(
      ref.read(providerRegistryProvider),
      seed,
      limit: startCount,
    );
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value.isEmpty:
        return const Err(NotFoundFailure(debugMessage: 'Nothing like it'));
      case Ok(:final value):
        _stopListening();
        ref.read(onlineTrackCacheProvider.notifier).remember([seed, ...value]);
        await player.setShuffleEnabled(false);
        await player.setQueue([seed, ...value], play: true);
        state = RadioState(seed: seed);
        _snapshots = player.snapshots.listen(_onSnapshot);
        return const Ok(null);
    }
  }

  void stop() {
    _stopListening();
    state = null;
  }

  void _onSnapshot(PlaybackSnapshot snapshot) {
    final radio = state;
    if (radio == null) return;
    if (!snapshot.queue.any((t) => t.id == radio.seed.id)) {
      stop();
      return;
    }
    final index = snapshot.currentIndex ?? 0;
    final left = snapshot.queue.length - 1 - index;
    if (left <= refillAt && !_refilling) unawaited(_refill(snapshot));
  }

  Future<void> _refill(PlaybackSnapshot snapshot) async {
    final radio = state;
    final player = ref.read(playbackControllerProvider);
    if (radio == null || player == null) return;
    _refilling = true;
    try {
      final from = snapshot.currentTrack ?? radio.seed;
      final result = await radioTracksFor(
        ref.read(providerRegistryProvider),
        from,
        limit: refillCount,
      );
      // The radio may have ended while the catalog answered.
      if (state != radio) return;
      if (result case Ok(:final value)) {
        final queued = {for (final t in player.snapshot.queue) t.id};
        final fresh = [
          for (final t in value)
            if (queued.add(t.id)) t,
        ];
        if (fresh.isEmpty) return;
        ref.read(onlineTrackCacheProvider.notifier).remember(fresh);
        await player.addToQueue(fresh);
      }
      // A failed refill is not retried at once: the next track change
      // asks again.
    } finally {
      _refilling = false;
    }
  }

  void _stopListening() {
    unawaited(_snapshots?.cancel());
    _snapshots = null;
  }
}

final radioProvider = NotifierProvider<RadioController, RadioState?>(
  RadioController.new,
);
