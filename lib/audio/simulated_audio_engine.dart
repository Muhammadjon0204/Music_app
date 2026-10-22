import 'dart:async';

import 'package:music_app/audio/audio_engine.dart';

/// SILENT ENGINE — plays no sound; a timer advances the position.
///
/// Used where no audio plugin exists (Windows/Linux development builds)
/// and in tests. The UI labels playback through it as silent. Mirrors
/// just_audio's semantics: `playing` stays true when a track completes.
final class SimulatedAudioEngine implements AudioEngine {
  SimulatedAudioEngine({this.tick = const Duration(milliseconds: 250)});

  final Duration tick;

  final _states = StreamController<AudioEngineState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  AudioEnginePhase _phase = AudioEnginePhase.idle;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _timer;
  bool _disposed = false;

  @override
  Stream<AudioEngineState> get states => _states.stream;

  /// The silent engine never fails after loading.
  @override
  Stream<AudioEngineError> get errors => const Stream.empty();

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get position => _position;

  @override
  Future<Duration?> load(
    AudioLocation location, {
    Duration? expectedDuration,
  }) async {
    if (_disposed) throw const AudioLoadInterrupted();
    if (expectedDuration == null || expectedDuration <= Duration.zero) {
      throw AudioLoadException('No duration known for $location');
    }
    _stopTimer();
    _duration = expectedDuration;
    _setPhase(AudioEnginePhase.ready);
    _setPosition(Duration.zero);
    if (_playing) _startTimer();
    return _duration;
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    _playing = true;
    if (_phase == AudioEnginePhase.ready) _startTimer();
    _emitState();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _playing = false;
    _stopTimer();
    _emitState();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || _phase == AudioEnginePhase.idle) return;
    final clamped = position.isNegative
        ? Duration.zero
        : (position > _duration ? _duration : position);
    _setPosition(clamped);
    if (_phase == AudioEnginePhase.completed && clamped < _duration) {
      _setPhase(AudioEnginePhase.ready);
      if (_playing) _startTimer();
    }
  }

  /// Nothing to make quieter; kept for the interface.
  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopTimer();
    unawaited(_states.close());
    unawaited(_positions.close());
  }

  void _onTick(Timer _) {
    final next = _position + tick;
    if (next < _duration) {
      _setPosition(next);
      return;
    }
    _stopTimer();
    _setPosition(_duration);
    _setPhase(AudioEnginePhase.completed);
  }

  void _startTimer() => _timer ??= Timer.periodic(tick, _onTick);

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setPhase(AudioEnginePhase phase) {
    _phase = phase;
    _emitState();
  }

  void _emitState() {
    if (!_disposed) {
      _states.add(AudioEngineState(phase: _phase, playing: _playing));
    }
  }

  void _setPosition(Duration value) {
    _position = value;
    if (!_disposed) _positions.add(value);
  }
}
