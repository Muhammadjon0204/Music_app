import 'dart:async';
import 'dart:math';

import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/audio_interruptions.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_queue.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Where the current track is in its life cycle. The published
/// [PlaybackStatus] combines this with the user's intent and the engine's
/// own state, so "playing" is only shown once the engine confirms it.
enum _TrackPhase { none, loading, ready, completed, failed }

/// The app's [PlaybackController]: queue rules from [PlaybackQueue], audio
/// from an [AudioEngine] (just_audio, or the silent engine).
///
/// Every load gets a token and a [Cancellation]; results, completion events
/// and errors from a load that has since been superseded (e.g. by rapid
/// "next" taps) are ignored, and its pending network work is cancelled.
///
/// [interruptions] (calls, alarms, other apps, headphones unplugged) are
/// handled here like Apple Music does: pause, then resume only if the
/// system allows it and the user has not taken over in the meantime.
///
/// Nothing is retried automatically: after a failure, the next "play"
/// retries once (resuming where the track stopped), "next" moves on.
final class EnginePlaybackController implements PlaybackController {
  EnginePlaybackController({
    required AudioEngine engine,
    Random? random,
    AudioResolver? resolver,
    Stream<AudioInterruption>? interruptions,
  }) : _engine = engine,
       _random = random ?? Random(),
       _resolve = resolver ?? TrackAudioResolver().call {
    _engineStates = engine.states.listen(_onEngineState);
    _engineErrors = engine.errors.listen(_onEngineError);
    _enginePositions = engine.positions.listen(_onEnginePosition);
    _interruptions = interruptions?.listen(
      (event) => unawaited(_onInterruption(event)),
    );
  }

  /// Volume while another app speaks over the music (Android ducking).
  static const duckedVolume = 0.3;

  final AudioEngine _engine;
  final Random _random;
  final AudioResolver _resolve;

  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  late final StreamSubscription<AudioEngineState> _engineStates;
  late final StreamSubscription<AudioEngineError> _engineErrors;
  late final StreamSubscription<Duration> _enginePositions;
  StreamSubscription<AudioInterruption>? _interruptions;

  PlaybackQueue _queue = PlaybackQueue.empty;
  PlaybackRepeatMode _repeat = PlaybackRepeatMode.off;
  _TrackPhase _phase = _TrackPhase.none;
  AudioEngineState _engineState = const AudioEngineState(
    phase: AudioEnginePhase.idle,
    playing: false,
  );

  /// What the engine has open for the current track.
  AudioLocation? _location;
  Duration? _duration;
  AppFailure? _failure;
  Duration _position = Duration.zero;
  PlaybackSnapshot _snapshot = PlaybackSnapshot.initial;

  /// Whether the user wants sound: survives track changes.
  bool _wantsPlay = false;

  /// Paused by an interruption while playing; resume when it ends.
  bool _resumeAfterInterruption = false;

  /// Where a failed track stopped, so a retry continues from there.
  Duration? _resumeAt;

  int _loadToken = 0;
  Cancellation? _loadCancellation;
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
  Future<void> setQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool play = false,
  }) async {
    if (_disposed) return;
    _resumeAfterInterruption = false;
    _resumeAt = null;
    var queue = PlaybackQueue(tracks, startIndex: startIndex);
    if (_queue.isShuffled) queue = queue.shuffled(_random);
    _queue = queue;
    _wantsPlay = play && queue.current != null;
    if (!play) await _engine.pause();
    if (queue.isEmpty) {
      _abandonLoad();
      _phase = _TrackPhase.none;
      _duration = null;
      _failure = null;
      _setPosition(Duration.zero);
      _publish();
      return;
    }
    await _loadCurrent();
  }

  @override
  Future<void> playNext(List<Track> tracks) => _edit(
    (queue) => queue.insertNext(tracks),
    loadsIfEmpty: tracks.isNotEmpty,
  );

  @override
  Future<void> addToQueue(List<Track> tracks) =>
      _edit((queue) => queue.append(tracks), loadsIfEmpty: tracks.isNotEmpty);

  @override
  Future<void> removeFromQueue(int index) async {
    if (_disposed || index == _queue.position) return;
    await _edit((queue) => queue.removeAt(index));
  }

  @override
  Future<void> moveInQueue(int from, int to) =>
      _edit((queue) => queue.move(from, to));

  /// Changes the queue without touching the current track's playback. An
  /// empty queue that gains tracks loads its first one, paused.
  Future<void> _edit(
    PlaybackQueue Function(PlaybackQueue queue) change, {
    bool loadsIfEmpty = false,
  }) async {
    if (_disposed) return;
    final wasEmpty = _queue.isEmpty;
    _queue = change(_queue);
    if (wasEmpty && loadsIfEmpty && !_queue.isEmpty) {
      await _loadCurrent();
      return;
    }
    _publish();
  }

  @override
  Future<void> play() async {
    if (_disposed || _queue.isEmpty) return;
    _resumeAfterInterruption = false;
    _wantsPlay = true;
    switch (_phase) {
      case _TrackPhase.completed:
        // Playing after the queue ended starts it over.
        _queue = _queue.jumpTo(0);
        _resumeAt = null;
        await _loadCurrent();
      case _TrackPhase.failed || _TrackPhase.none:
        // Nothing usable loaded (e.g. the last load failed): try once more.
        await _loadCurrent();
      case _TrackPhase.loading:
        // Plays when the load finishes.
        _publish();
      case _TrackPhase.ready:
        _publish();
        await _engine.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _resumeAfterInterruption = false;
    _wantsPlay = false;
    await _engine.pause();
    _publish();
  }

  @override
  Future<void> stop() async {
    await pause();
    await seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    var target = position.isNegative ? Duration.zero : position;
    final duration = _duration;
    if (duration != null && target > duration) target = duration;
    if (_phase == _TrackPhase.loading) {
      // Applied once the track is open, instead of being lost.
      _resumeAt = target;
      _setPosition(target);
      return;
    }
    if (_phase != _TrackPhase.ready && _phase != _TrackPhase.completed) {
      return;
    }
    if (_phase == _TrackPhase.completed && target < (duration ?? target)) {
      _phase = _TrackPhase.ready;
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
    _resumeAt = null;
    await _loadCurrent();
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
    _resumeAt = null;
    await _loadCurrent();
  }

  /// Choosing a track from the queue starts playing it.
  @override
  Future<void> skipToIndex(int index) async {
    if (_disposed) return;
    _queue = _queue.jumpTo(index);
    _wantsPlay = true;
    _resumeAt = null;
    await _loadCurrent();
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
    _abandonLoad();
    // Not awaited: there is nothing to wait for, and awaiting a broadcast
    // subscription's cancel can stall under the test framework's fake clock.
    unawaited(_engineStates.cancel());
    unawaited(_engineErrors.cancel());
    unawaited(_enginePositions.cancel());
    unawaited(_interruptions?.cancel());
    await _engine.dispose();
    unawaited(_snapshots.close());
    unawaited(_positions.close());
  }

  /// At most this many unplayable tracks in a row are skipped during
  /// automatic advance before the player stops and reports the failure.
  static const maxAutoSkips = 5;

  /// Unplayable tracks skipped in a row; reset by a successful load.
  int _autoSkips = 0;

  /// Loads the current track; plays it if the user wants sound by the time
  /// it is ready. [autoAdvance]: the queue moved on by itself, so a track
  /// that cannot play is skipped (bounded) instead of stopping the music.
  Future<void> _loadCurrent({bool autoAdvance = false}) async {
    _abandonLoad();
    final token = _loadToken;
    final cancellation = _loadCancellation = Cancellation();
    final track = _queue.current!;
    _phase = _TrackPhase.loading;
    _location = null;
    _failure = null;
    _duration = track.duration;
    _setPosition(Duration.zero);
    _publish();

    final AudioLocation location;
    switch (await _resolve(track, cancellation)) {
      case Ok(:final value):
        location = value;
      case Err(:final failure):
        if (!_isCurrent(token)) return;
        await _failOrSkip(failure, autoAdvance: autoAdvance);
        return;
    }
    if (!_isCurrent(token)) return;
    _location = location;

    try {
      final duration = await _engine.load(
        location,
        expectedDuration: track.duration,
      );
      if (!_isCurrent(token)) return;
      _autoSkips = 0;
      _phase = _TrackPhase.ready;
      _duration = duration ?? track.duration;
      final resumeAt = _resumeAt;
      _resumeAt = null;
      if (resumeAt != null && resumeAt > Duration.zero) {
        _setPosition(resumeAt);
        await _engine.seek(resumeAt);
        if (!_isCurrent(token)) return;
      }
      _publish();
      if (_wantsPlay) await _engine.play();
    } on AudioLoadInterrupted {
      return;
    } on AudioLoadException catch (e, stackTrace) {
      if (!_isCurrent(token)) return;
      await _failOrSkip(
        _failureFor(
          e.kind,
          location,
          duringLoad: true,
          debugMessage: e.detail,
          cause: e,
          stackTrace: stackTrace,
        ),
        autoAdvance: autoAdvance,
      );
    }
  }

  /// During automatic advance, a track that can never play here (removed,
  /// blocked, unsupported) is skipped like a dead track in Apple Music.
  /// Connection problems stop instead: the next track would fail the same
  /// way, and skipping would silently empty the queue.
  Future<void> _failOrSkip(
    AppFailure failure, {
    required bool autoAdvance,
  }) async {
    final next = _queue.next(_repeat, AdvanceReason.userSkipped);
    final canSkip =
        autoAdvance &&
        _isTrackSpecific(failure) &&
        _autoSkips < maxAutoSkips &&
        next != null &&
        next.position != _queue.position;
    if (!canSkip) {
      _autoSkips = 0;
      _fail(failure);
      return;
    }
    _autoSkips++;
    _queue = next;
    await _loadCurrent(autoAdvance: true);
  }

  static bool _isTrackSpecific(AppFailure failure) => switch (failure) {
    NotFoundFailure() ||
    AccessDeniedFailure() ||
    UnsupportedMediaFailure() ||
    FileAccessFailure() ||
    FeatureUnavailableFailure() ||
    InvalidResponseFailure() => true,
    _ => false,
  };

  /// Makes any load in flight stale and cancels its network work.
  void _abandonLoad() {
    _loadToken++;
    _loadCancellation?.cancel();
    _loadCancellation = null;
  }

  bool _isCurrent(int token) => token == _loadToken && !_disposed;

  /// Stops on a failed track and reports it; the user decides what next
  /// (play retries once, next moves on). Never retried automatically.
  void _fail(AppFailure failure) {
    if (_phase == _TrackPhase.ready && _position > Duration.zero) {
      _resumeAt = _position;
    }
    _failure = failure;
    _phase = _TrackPhase.failed;
    _wantsPlay = false;
    unawaited(_engine.pause());
    _publish();
  }

  Future<void> _onInterruption(AudioInterruption event) async {
    if (_disposed) return;
    switch (event) {
      case AudioInterruption.began:
        if (!_wantsPlay) return;
        await pause();
        // Set after pause(), which clears it.
        _resumeAfterInterruption = true;
      case AudioInterruption.endedMayResume:
        if (_resumeAfterInterruption) await play();
      case AudioInterruption.endedNoResume:
        _resumeAfterInterruption = false;
      case AudioInterruption.beganDuck:
        await _engine.setVolume(duckedVolume);
      case AudioInterruption.endedDuck:
        await _engine.setVolume(1);
      case AudioInterruption.becameNoisy:
        // Never resumes by itself: reconnecting headphones should not
        // start the music.
        if (_wantsPlay) await pause();
    }
  }

  void _onEngineState(AudioEngineState state) {
    if (_disposed) return;
    _engineState = state;
    // Only events for a loaded track matter; during a load the engine still
    // reports on the previous source.
    if (_phase != _TrackPhase.ready) return;
    if (state.phase == AudioEnginePhase.completed && _wantsPlay) {
      unawaited(_onTrackCompleted());
      return;
    }
    _publish();
  }

  void _onEngineError(AudioEngineError error) {
    // Errors while loading arrive as AudioLoadException instead.
    if (_disposed || _phase != _TrackPhase.ready) return;
    _fail(
      _failureFor(
        error.kind,
        _location,
        duringLoad: false,
        debugMessage: error.detail,
        cause: error,
      ),
    );
  }

  /// The user-facing failure for an engine error. Unknown causes are not
  /// guessed: a local file that will not open is reported as an unsupported
  /// format (as before), anything else as a generic playback failure.
  static AppFailure _failureFor(
    AudioErrorKind kind,
    AudioLocation? location, {
    required bool duringLoad,
    required String debugMessage,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    final isStream = location is StreamAudio;
    final where = isStream ? 'stream' : 'local';
    final message = '$where: $debugMessage';
    return switch (kind) {
      AudioErrorKind.networkUnavailable => NetworkFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.timeout => TimeoutFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.notFound => NotFoundFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.fileMissing when isStream => NotFoundFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.fileMissing => FileAccessFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.accessDenied => AccessDeniedFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.rateLimited => RateLimitedFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.server => ServerFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.unsupportedFormat => UnsupportedMediaFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
      AudioErrorKind.unknown when duringLoad && !isStream =>
        UnsupportedMediaFailure(
          debugMessage: message,
          cause: cause,
          stackTrace: stackTrace,
        ),
      AudioErrorKind.unknown => PlaybackFailure(
        debugMessage: message,
        cause: cause,
        stackTrace: stackTrace,
      ),
    };
  }

  Future<void> _onTrackCompleted() async {
    final next = _queue.next(_repeat, AdvanceReason.trackCompleted);
    if (next == null) {
      _wantsPlay = false;
      _phase = _TrackPhase.completed;
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
    await _loadCurrent(autoAdvance: true);
  }

  void _onEnginePosition(Duration position) {
    if (_phase == _TrackPhase.ready) _setPosition(position);
  }

  void _setPosition(Duration value) {
    _position = value;
    if (!_disposed) _positions.add(value);
  }

  PlaybackStatus get _status => switch (_phase) {
    _TrackPhase.none => PlaybackStatus.idle,
    _TrackPhase.loading => PlaybackStatus.loading,
    _TrackPhase.completed => PlaybackStatus.completed,
    _TrackPhase.failed => PlaybackStatus.failed,
    _TrackPhase.ready when !_wantsPlay => PlaybackStatus.paused,
    _TrackPhase.ready
        when _engineState.playing &&
            _engineState.phase == AudioEnginePhase.ready =>
      PlaybackStatus.playing,
    _TrackPhase.ready => PlaybackStatus.buffering,
  };

  void _publish() {
    if (_disposed) return;
    final snapshot = PlaybackSnapshot(
      queue: _queue.playOrder,
      currentIndex: _queue.isEmpty ? null : _queue.position,
      status: _status,
      playWhenReady: _wantsPlay,
      shuffleEnabled: _queue.isShuffled,
      repeatMode: _repeat,
      duration: _duration,
      failure: _failure,
    );
    if (snapshot == _snapshot) return;
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }
}
