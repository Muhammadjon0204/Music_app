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
  int playCalls = 0;
  int pauseCalls = 0;
  List<Track>? lastQueue;
  int? lastStartIndex;
  bool? shuffleEnabled;

  void emit(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _updates.add(snapshot);
  }

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _updates.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Stream<Duration> get positions => const Stream.empty();

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    lastQueue = tracks;
    lastStartIndex = startIndex;
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> skipToIndex(int index) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async =>
      shuffleEnabled = enabled;

  @override
  Future<void> setRepeatMode(PlaybackRepeatMode mode) async {}

  @override
  Future<void> dispose() => _updates.close();
}

/// Audio engine whose loads, failures and events the test controls.
class FakeAudioEngine implements AudioEngine {
  final _states = StreamController<AudioEngineState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();

  final loads = <AudioLocation>[];
  final seeks = <Duration>[];
  int playCalls = 0;
  int pauseCalls = 0;
  bool disposed = false;

  /// When true, each load waits for [finishLoad]; a newer load interrupts
  /// the pending one, as just_audio does.
  bool holdLoads = false;
  Completer<Duration?>? _pending;

  /// Thrown by the next load.
  Object? failNextLoad;

  Duration _position = Duration.zero;

  void emit(AudioEngineState state) => _states.add(state);

  void moveTo(Duration position) {
    _position = position;
    _positions.add(position);
  }

  void finishLoad([Duration? duration]) {
    final pending = _pending;
    _pending = null;
    pending?.complete(duration);
  }

  @override
  Stream<AudioEngineState> get states => _states.stream;

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Duration get position => _position;

  @override
  Future<Duration?> load(AudioLocation location, {Duration? expectedDuration}) {
    loads.add(location);
    final failure = failNextLoad;
    if (failure != null) {
      failNextLoad = null;
      return Future.error(failure);
    }
    if (holdLoads) {
      _pending?.completeError(const AudioLoadInterrupted());
      final pending = Completer<Duration?>();
      _pending = pending;
      return pending.future;
    }
    return Future.value(expectedDuration);
  }

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    _position = position;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(_states.close());
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
