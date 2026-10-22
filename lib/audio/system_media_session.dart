import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Mirrors the app's [PlaybackController] to the system: lock screen,
/// Control Center, AirPods and headphone buttons, CarPlay's Now Playing,
/// the browser's media keys. Commands from there go to the same
/// controller the app's own buttons use, so both always agree.
///
/// Position is sent only when it jumps (seek, track change, pause): the
/// system extrapolates it from [PlaybackState.updateTime] while playing.
final class SystemMediaSession extends BaseAudioHandler {
  SystemMediaSession(
    this._controller, {
    this._artworkPath,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _snapshots = _controller.snapshots.listen(_onSnapshot);
    _positions = _controller.positions.listen(_onPosition);
    _onSnapshot(_controller.snapshot);
  }

  /// Platforms where audio_service shows system controls. Android also
  /// needs manifest and activity changes, planned with the Android port.
  static bool get isSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => true,
        _ => false,
      };

  /// A position this far from the extrapolated one is republished.
  static const positionTolerance = Duration(seconds: 1);

  final PlaybackController _controller;
  final String? Function(Uri artwork)? _artworkPath;
  final DateTime Function() _now;
  late final StreamSubscription<PlaybackSnapshot> _snapshots;
  late final StreamSubscription<Duration> _positions;

  (Track, Duration?)? _shownItem;

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  /// The system's "stop" (e.g. a dismissed notification) only pauses: the
  /// queue stays so the user can continue in the app.
  @override
  Future<void> stop() => _controller.pause();

  @override
  Future<void> seek(Duration position) => _controller.seek(position);

  @override
  Future<void> skipToNext() => _controller.skipToNext();

  @override
  Future<void> skipToPrevious() => _controller.skipToPrevious();

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _controller.setShuffleEnabled(
        shuffleMode != AudioServiceShuffleMode.none,
      );

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _controller.setRepeatMode(switch (repeatMode) {
        AudioServiceRepeatMode.none => PlaybackRepeatMode.off,
        AudioServiceRepeatMode.one => PlaybackRepeatMode.one,
        AudioServiceRepeatMode.all ||
        AudioServiceRepeatMode.group => PlaybackRepeatMode.all,
      });

  /// Stops mirroring. The controller itself is owned elsewhere.
  Future<void> dispose() async {
    await _snapshots.cancel();
    await _positions.cancel();
  }

  void _onSnapshot(PlaybackSnapshot snapshot) {
    final track = snapshot.currentTrack;
    final duration = snapshot.duration ?? track?.duration;
    final item = track == null ? null : (track, duration);
    if (item != _shownItem) {
      _shownItem = item;
      mediaItem.add(track == null ? null : _mediaItemFor(track, duration));
    }
    _publishState(snapshot, _controller.position);
  }

  void _onPosition(Duration position) {
    final state = playbackState.value;
    // The system advances the position only while really playing.
    final advancing =
        state.playing && state.processingState == AudioProcessingState.ready;
    final expected = advancing
        ? state.updatePosition + _now().difference(state.updateTime)
        : state.updatePosition;
    if ((position - expected).abs() > positionTolerance) {
      _publishState(_controller.snapshot, position);
    }
  }

  void _publishState(PlaybackSnapshot snapshot, Duration position) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          // Follows intent: while buffering, "pause" is what the user needs.
          if (snapshot.playWhenReady) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: switch (snapshot.status) {
          PlaybackStatus.idle => AudioProcessingState.idle,
          PlaybackStatus.loading => AudioProcessingState.loading,
          PlaybackStatus.buffering => AudioProcessingState.buffering,
          PlaybackStatus.playing ||
          PlaybackStatus.paused => AudioProcessingState.ready,
          PlaybackStatus.completed => AudioProcessingState.completed,
          PlaybackStatus.failed => AudioProcessingState.error,
        },
        // audio_service's meaning: playing, or will play once ready.
        playing: snapshot.playWhenReady,
        updatePosition: position,
        updateTime: _now(),
        queueIndex: snapshot.currentIndex,
        shuffleMode: snapshot.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (snapshot.repeatMode) {
          PlaybackRepeatMode.off => AudioServiceRepeatMode.none,
          PlaybackRepeatMode.one => AudioServiceRepeatMode.one,
          PlaybackRepeatMode.all => AudioServiceRepeatMode.all,
        },
      ),
    );
  }

  MediaItem _mediaItemFor(Track track, Duration? duration) {
    return MediaItem(
      id: track.id.value,
      title: track.title,
      artist: track.artistName,
      album: track.albumTitle,
      duration: duration,
      artUri: _artUri(track.artworkUri),
    );
  }

  /// Online covers are passed as their HTTPS URL; library covers as a file.
  Uri? _artUri(Uri? artwork) {
    if (artwork == null) return null;
    if (artwork.isScheme('https')) return artwork;
    final path = _artworkPath?.call(artwork);
    return path == null ? null : Uri.file(path);
  }
}
