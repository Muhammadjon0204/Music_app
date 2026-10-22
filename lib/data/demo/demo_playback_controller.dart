import 'dart:async';
import 'dart:math';

import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_queue.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// DEMO PLAYER — drives the player UI with a timer and plays **no sound**.
///
/// Exists so the player screens can be built and reviewed before the audio
/// engine (Phase 6). The UI labels it as demo. Queue rules come from
/// [PlaybackQueue], which the real engine will reuse.
final class DemoPlaybackController implements PlaybackController {
  DemoPlaybackController({
    Random? random,
    this.tick = const Duration(milliseconds: 250),
  }) : _random = random ?? Random();

  final Duration tick;
  final Random _random;

  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  PlaybackQueue _queue = PlaybackQueue.empty;
  PlaybackStatus _status = PlaybackStatus.idle;
  PlaybackRepeatMode _repeat = PlaybackRepeatMode.off;
  Duration _position = Duration.zero;
  PlaybackSnapshot _snapshot = PlaybackSnapshot.initial;
  Timer? _timer;
  bool _disposed = false;

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Duration get position => _position;

  @override
  Stream<Duration> get positions => _positions.stream;

  Duration get _duration => _queue.current?.duration ?? Duration.zero;

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (_disposed) return;
    var queue = PlaybackQueue(tracks, startIndex: startIndex);
    if (_queue.isShuffled) queue = queue.shuffled(_random);
    _queue = queue;
    _status = queue.isEmpty ? PlaybackStatus.idle : PlaybackStatus.paused;
    _stopTimer();
    _setPosition(Duration.zero);
    _publish();
  }

  @override
  Future<void> play() async {
    if (_disposed || _queue.isEmpty) return;
    if (_status == PlaybackStatus.completed) {
      // Playing after the queue ended starts it over.
      _queue = _queue.jumpTo(0);
      _setPosition(Duration.zero);
    }
    _status = PlaybackStatus.playing;
    _startTimer();
    _publish();
  }

  @override
  Future<void> pause() async {
    if (_disposed || _status != PlaybackStatus.playing) return;
    _status = PlaybackStatus.paused;
    _stopTimer();
    _publish();
  }

  @override
  Future<void> stop() async {
    if (_disposed || _queue.isEmpty) return;
    _status = PlaybackStatus.paused;
    _stopTimer();
    _setPosition(Duration.zero);
    _publish();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed || _queue.isEmpty) return;
    _setPosition(_clamp(position));
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed) return;
    final next = _queue.next(_repeat, AdvanceReason.userSkipped);
    if (next == null) return;
    _moveTo(next);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed || _queue.isEmpty) return;
    final previous = _queue.previous(_repeat);
    if (_position > previousRestartThreshold || previous == null) {
      _setPosition(Duration.zero);
      return;
    }
    _moveTo(previous);
  }

  @override
  Future<void> skipToIndex(int index) async {
    if (_disposed) return;
    _moveTo(_queue.jumpTo(index));
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
    _stopTimer();
    await _snapshots.close();
    await _positions.close();
  }

  void _moveTo(PlaybackQueue queue) {
    _queue = queue;
    if (_status == PlaybackStatus.completed) _status = PlaybackStatus.paused;
    _setPosition(Duration.zero);
    _publish();
  }

  void _onTick(Timer _) {
    final advanced = _position + tick;
    if (advanced < _duration) {
      _setPosition(advanced);
      return;
    }
    final next = _queue.next(_repeat, AdvanceReason.trackCompleted);
    if (next == null) {
      _status = PlaybackStatus.completed;
      _stopTimer();
      _setPosition(_duration);
      _publish();
      return;
    }
    _queue = next;
    _setPosition(Duration.zero);
    _publish();
  }

  void _startTimer() {
    _timer ??= Timer.periodic(tick, _onTick);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Duration _clamp(Duration value) {
    if (value.isNegative) return Duration.zero;
    return value > _duration ? _duration : value;
  }

  void _setPosition(Duration value) {
    _position = value;
    _positions.add(value);
  }

  void _publish() {
    _snapshot = PlaybackSnapshot(
      queue: _queue.playOrder,
      currentIndex: _queue.isEmpty ? null : _queue.position,
      status: _status,
      shuffleEnabled: _queue.isShuffled,
      repeatMode: _repeat,
      duration: _queue.current?.duration,
    );
    _snapshots.add(_snapshot);
  }
}
