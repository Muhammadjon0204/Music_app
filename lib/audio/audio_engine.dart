/// Where a track's audio can be read from.
sealed class AudioLocation {
  const AudioLocation();
}

final class AssetAudio extends AudioLocation {
  const AssetAudio(this.path);

  final String path;

  @override
  String toString() => 'AssetAudio($path)';
}

final class FileAudio extends AudioLocation {
  const FileAudio(this.path);

  final String path;

  @override
  String toString() => 'FileAudio(<file>)';
}

/// An HTTPS audio stream. The URL may redirect to a temporary signed URL;
/// the engine follows it. Never stored: it is resolved again next time.
final class StreamAudio extends AudioLocation {
  StreamAudio(this.uri, {Map<String, String> headers = const {}})
    : headers = Map.unmodifiable(headers) {
    if (!uri.isScheme('https')) {
      throw ArgumentError.value(uri.scheme, 'uri', 'must be https');
    }
  }

  final Uri uri;
  final Map<String, String> headers;

  /// Host only: paths and queries can contain signatures or user data.
  @override
  String toString() => 'StreamAudio(${uri.host})';
}

/// [loading]: opening the source. [buffering]: opened, waiting for data
/// (a stream on a slow network).
enum AudioEnginePhase { idle, loading, buffering, ready, completed }

/// Why the engine could not open or keep playing audio, as far as the
/// platform tells. [unknown] when it does not say: never guessed.
enum AudioErrorKind {
  networkUnavailable,
  timeout,
  notFound,
  accessDenied,
  rateLimited,
  server,
  unsupportedFormat,
  fileMissing,
  unknown,
}

/// An error the engine reported while a source was loaded.
final class AudioEngineError {
  const AudioEngineError(this.kind, this.detail);

  final AudioErrorKind kind;

  /// Developer-facing detail; never shown to users.
  final String detail;

  @override
  String toString() => 'AudioEngineError($kind, $detail)';
}

final class AudioEngineState {
  const AudioEngineState({required this.phase, required this.playing});

  final AudioEnginePhase phase;
  final bool playing;

  @override
  bool operator ==(Object other) =>
      other is AudioEngineState &&
      other.phase == phase &&
      other.playing == playing;

  @override
  int get hashCode => Object.hash(phase, playing);

  @override
  String toString() => 'AudioEngineState($phase, playing: $playing)';
}

/// The audio could not be opened or decoded.
final class AudioLoadException implements Exception {
  const AudioLoadException(this.detail, {this.kind = AudioErrorKind.unknown});

  /// Developer-facing detail; never shown to users.
  final String detail;
  final AudioErrorKind kind;

  @override
  String toString() => 'AudioLoadException($kind, $detail)';
}

/// A newer load replaced this one before it finished.
final class AudioLoadInterrupted implements Exception {
  const AudioLoadInterrupted();
}

/// Thin wrapper around a platform audio player, so playback rules can be
/// tested without plugins and the plugin can be replaced in one place.
abstract interface class AudioEngine {
  Stream<AudioEngineState> get states;

  /// Errors after a source was loaded (e.g. the network drops mid-stream).
  Stream<AudioEngineError> get errors;

  Stream<Duration> get positions;

  Duration get position;

  /// Loads [location] and returns its duration when known.
  ///
  /// [expectedDuration] comes from metadata; engines that cannot measure
  /// the audio may use it. Throws [AudioLoadException] or
  /// [AudioLoadInterrupted].
  Future<Duration?> load(AudioLocation location, {Duration? expectedDuration});

  /// Requests playback and returns without waiting for it to finish.
  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// 0 (silent) to 1 (full).
  Future<void> setVolume(double volume);

  Future<void> dispose();
}
