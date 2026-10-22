import 'dart:async';
import 'dart:math';

import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_queue.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// The app's [PlaybackController]: queue rules from [PlaybackQueue], audio
/// from an [AudioEngine] (just_audio, or the silent engine).
///
/// Every load gets a token; results and completion events from a load that
/// has since been superseded (e.g. by rapid "next" taps) are ignored.
final class EnginePlaybackController implements PlaybackController {
  EnginePlaybackController({
    required AudioEngine engine,
    Random? random,
    Result<AudioLocation> Function(Track track) resolver = resolveTrackAudio,
  }) : _engine = engine,
       _random = random ?? Random(),
       _resolve = resolver {
    _engineStates = engine.states.listen(_onEngineState);
    _enginePositions = engine.positions.listen(_onEnginePosition);
  }

  final AudioEngine _engine;
  final Random _random;
  final Result<AudioLocation> Function(Track) _resolve;

  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  late final StreamSubscription<AudioEngineState> _engineStates;
  late final StreamSubscription<Duration> _enginePositions;

  PlaybackQueue _queue = PlaybackQueue.empty;
  PlaybackRepeatMode _repeat = PlaybackRepeatMode.off;
  PlaybackStatus _status = PlaybackStatus.idle;
  Duration? _duration;
  AppFailure? _failure;
  Duration _position = Duration.zero;
  PlaybackSnapshot _snapshot = PlaybackSnapshot.initial;

  /// Whether the user wants sound: survives track changes.
  bool _wantsPlay = false;

  /// True once the current track is loaded and ready in the engine.
  bool _loaded = false;
  int _loadToken = 0;
  bool _disposed = false;

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Duration get position => _position;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (_disposed) return;
    var queue = PlaybackQueue(tracks, startIndex: startIndex);
    if (_queue.isShuffled) queue = queue.shuffled(_random);
    _queue = queue;
    _wantsPlay = false;
    await _engine.pause();
    if (queue.isEmpty) {
      _loadToken++;
      _loaded = false;
      _status = PlaybackStatus.idle;
      _duration = null;
      _failure = null;
      _setPosition(Duration.zero);
      _publish();
      return;
    }
    await _loadCurrent(autoplay: false);
  }

  @override
  Future<void> play() async {
    if (_disposed || _queue.isEmpty) return;
    _wantsPlay = true;
    if (_status == PlaybackStatus.completed) {
      // Playing after the queue ended starts it over.
      _queue = _queue.jumpTo(0);
      await _loadCurrent(autoplay: true);
      return;
    }
    if (!_loaded) {
      // Nothing usable loaded yet (e.g. the last load failed): try again.
      if (_status != PlaybackStatus.loading) {
        await _loadCurrent(autoplay: true);
      }
      return;
    }
    _status = PlaybackStatus.playing;
    _publish();
    await _engine.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _wantsPlay = false;
    await _engine.pause();
    if (_status == PlaybackStatus.playing ||
        _status == PlaybackStatus.loading) {
      _status = PlaybackStatus.paused;
      _publish();
    }
  }

  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || !_loaded) return;
    var target = position.isNegative ? Duration.zero : position;
    final duration = _duration;
    if (duration != null && target > duration) target = duration;
    if (_status == PlaybackStatus.completed && target < (duration ?? target)) {
      _status = PlaybackStatus.paused;
      _publish();
    }
    _setPosition(target);
    await _engine.seek(target);
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed) return;
    final next = _queue.next(_repeat, AdvanceReason.userSkipped);
    if (next == null) return;
    _queue = next;
    await _loadCurrent(autoplay: _wantsPlay);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed || _queue.isEmpty) return;
    final previous = _queue.previous(_repeat);
    if (_position > previousRestartThreshold || previous == null) {
      await seek(Duration.zero);
      return;
    }
    _queue = previous;
    await _loadCurrent(autoplay: _wantsPlay);
  }

  /// Choosing a track from the queue starts playing it.
  @override
  Future<void> skipToIndex(int index) async {
    if (_disposed) return;
    _queue = _queue.jumpTo(index);
    _wantsPlay = true;
    await _loadCurrent(autoplay: true);
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    if (_disposed) return;
    _queue = enabled ? _queue.shuffled(_random) : _queue.unshuffled();
    _publish();
  }

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) async {
    if (_disposed) return;
    _repeat = mode;
    _publish();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _loadToken++;
    // Not awaited: there is nothing to wait for, and awaiting a broadcast
    // subscription's cancel can stall under the test framework's fake clock.
    unawaited(_engineStates.cancel());
    unawaited(_enginePositions.cancel());
    await _engine.dispose();
    unawaited(_snapshots.close());
    unawaited(_positions.close());
  }

  Future<void> _loadCurrent({required bool autoplay}) async {
    final token = ++_loadToken;
    final track = _queue.current!;
    _loaded = false;
    _failure = null;
    _duration = track.duration;
    _status = PlaybackStatus.loading;
    _setPosition(Duration.zero);
    _publish();

    final AudioLocation location;
    switch (_resolve(track)) {
      case Ok(:final value):
        location = value;
      case Err(:final failure):
        _fail(failure);
        return;
    }

    try {
      final duration = await _engine.load(
        location,
        expectedDuration: track.duration,
      );
      if (token != _loadToken || _disposed) return;
      _loaded = true;
      _duration = duration ?? track.duration;
      if (autoplay) {
        _status = PlaybackStatus.playing;
        _publish();
        await _engine.play();
      } else {
        _status = PlaybackStatus.paused;
        _publish();
      }
    } on AudioLoadInterrupted {
      return;
    } on AudioLoadException catch (e, stackTrace) {
      if (token != _loadToken || _disposed) return;
      _fail(
        UnsupportedMediaFailure(
          debugMessage: e.detail,
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Stops on a failed track and reports it; the user decides what next.
  void _fail(AppFailure failure) {
    _failure = failure;
    _loaded = false;
    _wantsPlay = false;
    _status = PlaybackStatus.paused;
    _publish();
  }

  void _onEngineState(AudioEngineState state) {
    // Only completion drives the queue. Pauses from outside the app
    // (calls, headphones) are handled with the audio session in Phase 8.
    if (_disposed ||
        !_loaded ||
        state.phase != AudioEnginePhase.completed ||
        _status != PlaybackStatus.playing) {
      return;
    }
    unawaited(_onTrackCompleted());
  }

  Future<void> _onTrackCompleted() async {
    final next = _queue.next(_repeat, AdvanceReason.trackCompleted);
    if (next == null) {
      _wantsPlay = false;
      _status = PlaybackStatus.completed;
      _setPosition(_duration ?? _position);
      _publish();
      await _engine.pause();
      return;
    }
    if (next == _queue) {
      // Repeat one: the engine keeps playing from the start.
      _setPosition(Duration.zero);
      await _engine.seek(Duration.zero);
      return;
    }
    _queue = next;
    await _loadCurrent(autoplay: true);
  }

  void _onEnginePosition(Duration position) {
    if (_loaded && _status != PlaybackStatus.completed) _setPosition(position);
  }

  void _setPosition(Duration value) {
    _position = value;
    if (!_disposed) _positions.add(value);
  }

  void _publish() {
    if (_disposed) return;
    _snapshot = PlaybackSnapshot(
      queue: _queue.playOrder,
      currentIndex: _queue.isEmpty ? null : _queue.position,
      status: _status,
      shuffleEnabled: _queue.isShuffled,
      repeatMode: _repeat,
      duration: _duration,
      failure: _failure,
    );
    _snapshots.add(_snapshot);
  }
}
