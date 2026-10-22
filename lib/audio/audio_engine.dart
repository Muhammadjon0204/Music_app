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

enum AudioEnginePhase { idle, loading, ready, completed }

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
  const AudioLoadException(this.detail);

  /// Developer-facing detail; never shown to users.
  final String detail;

  @override
  String toString() => 'AudioLoadException($detail)';
}

/// A newer load replaced this one before it finished.
final class AudioLoadInterrupted implements Exception {
  const AudioLoadInterrupted();
}

/// Thin wrapper around a platform audio player, so playback rules can be
/// tested without plugins and the plugin can be replaced in one place.
abstract interface class AudioEngine {
  Stream<AudioEngineState> get states;

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

  Future<void> dispose();
}
