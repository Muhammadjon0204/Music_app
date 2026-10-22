import 'dart:async';

import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Records commands; never plays audio.
class FakePlaybackController implements PlaybackController {
  FakePlaybackController(this._snapshot);

  PlaybackSnapshot _snapshot;
  final _updates = StreamController<PlaybackSnapshot>.broadcast();
  final _positionUpdates = StreamController<Duration>.broadcast();
  Duration _position = Duration.zero;
  int playCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;
  final seeks = <Duration>[];
  PlaybackRepeatMode? repeatMode;
  List<Track>? lastQueue;
  int? lastStartIndex;
  bool? shuffleEnabled;

  void emit(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _updates.add(snapshot);
  }

  void emitPosition(Duration position) {
    _position = position;
    _positionUpdates.add(position);
  }

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _updates.stream;

  @override
  Duration get position => _position;

  @override
  Stream<Duration> get positions => _positionUpdates.stream;

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    lastQueue = tracks;
    lastStartIndex = startIndex;
  }

  @override
  Future<void> skipToNext() async => nextCalls++;

  @override
  Future<void> skipToPrevious() async => previousCalls++;

  @override
  Future<void> skipToIndex(int index) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async =>
      shuffleEnabled = enabled;

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) async =>
      repeatMode = mode;

  @override
  Future<void> dispose() async {
    unawaited(_updates.close());
    unawaited(_positionUpdates.close());
  }
}

/// Audio engine whose loads, failures and events the test controls.
///
/// Behaves like just_audio: a load reports `loading` then `ready`, play and
/// pause report the new `playing` flag. Events are delivered synchronously
/// so tests can assert right after a command.
class FakeAudioEngine implements AudioEngine {
  final _states = StreamController<AudioEngineState>.broadcast(sync: true);
  final _errors = StreamController<AudioEngineError>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast();

  final loads = <AudioLocation>[];
  final seeks = <Duration>[];
  int playCalls = 0;
  int pauseCalls = 0;
  final volumes = <double>[];
  bool disposed = false;

  /// When true, each load waits for [finishLoad]; a newer load interrupts
  /// the pending one, as just_audio does.
  bool holdLoads = false;
  Completer<Duration?>? _pending;

  /// Thrown by the next load.
  Object? failNextLoad;

  /// When true, play() leaves the engine buffering (a slow stream) until
  /// the test emits `ready`.
  bool bufferOnPlay = false;

  Duration _position = Duration.zero;
  AudioEnginePhase _phase = AudioEnginePhase.idle;
  bool _playing = false;

  bool get isPlaying => _playing;

  /// Whether anyone still listens to the engine's streams.
  bool get hasListeners =>
      _states.hasListener || _errors.hasListener || _positions.hasListener;

  bool _emitting = false;

  void emit(AudioEngineState state) {
    _phase = state.phase;
    _playing = state.playing;
    // A listener reacting to an event with a command (pause after
    // completion) must not re-enter the synchronous stream.
    if (_emitting) {
      scheduleMicrotask(() => _states.add(state));
      return;
    }
    _emitting = true;
    try {
      _states.add(state);
    } finally {
      _emitting = false;
    }
  }

  /// An error after loading, like a network drop mid-stream.
  void failPlayback(AudioErrorKind kind, [String detail = 'test']) =>
      _errors.add(AudioEngineError(kind, detail));

  void moveTo(Duration position) {
    _position = position;
    _positions.add(position);
  }

  void finishLoad([Duration? duration]) {
    final pending = _pending;
    _pending = null;
    if (pending == null) return;
    _setPhase(AudioEnginePhase.ready);
    pending.complete(duration);
  }

  void _setPhase(AudioEnginePhase phase) =>
      emit(AudioEngineState(phase: phase, playing: _playing));

  @override
  Stream<AudioEngineState> get states => _states.stream;

  @override
  Stream<AudioEngineError> get errors => _errors.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get position => _position;

  @override
  Future<Duration?> load(AudioLocation location, {Duration? expectedDuration}) {
    loads.add(location);
    _setPhase(AudioEnginePhase.loading);
    final failure = failNextLoad;
    if (failure != null) {
      failNextLoad = null;
      _setPhase(AudioEnginePhase.idle);
      return Future.error(failure);
    }
    if (holdLoads) {
      _pending?.completeError(const AudioLoadInterrupted());
      final pending = Completer<Duration?>();
      _pending = pending;
      return pending.future;
    }
    _setPhase(AudioEnginePhase.ready);
    return Future.value(expectedDuration);
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> play() async {
    playCalls++;
    _playing = true;
    _setPhase(bufferOnPlay ? AudioEnginePhase.buffering : _phase);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playing = false;
    _setPhase(_phase);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(_states.close());
    unawaited(_errors.close());
    unawaited(_positions.close());
  }
}

/// Home feed source whose result the test controls.
class FakeHomeFeedSource implements HomeFeedSource {
  FakeHomeFeedSource(this.respond);

  Future<Result<HomeFeed>> Function() respond;
  int calls = 0;

  @override
  Future<Result<HomeFeed>> load() {
    calls++;
    return respond();
  }
}
