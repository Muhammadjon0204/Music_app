import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// Picks the first source of [track] that this build can play.
///
/// [resolveFile] turns a stored file reference (e.g. `library:audio/x.mp3`)
/// into an absolute path; [fileExists] lets a missing file be reported
/// precisely instead of as a decoding error. Online sources are skipped
/// until a provider integration exists (Phase 10).
Result<AudioLocation> resolveTrackAudio(
  Track track, {
  String? Function(String reference)? resolveFile,
  bool Function(String path)? fileExists,
}) {
  for (final source in track.sources) {
    switch (source) {
      case BundledAudioSource(:final assetPath):
        return Ok(AssetAudio(assetPath));
      case LocalFileSource(:final fileReference):
        // Library references need [resolveFile]; anything else is a path.
        final path =
            resolveFile?.call(fileReference) ??
            (fileReference.startsWith('library:') ? null : fileReference);
        if (path == null) {
          return Err(
            FileAccessFailure(
              debugMessage: 'Unresolvable file reference for ${track.id.value}',
            ),
          );
        }
        if (fileExists != null && !fileExists(path)) {
          return Err(
            FileAccessFailure(
              debugMessage: 'Missing file for ${track.id.value}',
            ),
          );
        }
        return Ok(FileAudio(path));
      case ProviderTrackSource():
        continue;
    }
  }
  return Err(
    UnsupportedMediaFailure(
      debugMessage: 'No playable source for track ${track.id.value}',
    ),
  );
}
