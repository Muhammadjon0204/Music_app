import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// Picks the first source of [track] that this build can play.
///
/// Online sources are skipped until a provider integration exists
/// (Phase 10); a track with only online sources is unplayable for now.
Result<AudioLocation> resolveTrackAudio(Track track) {
  for (final source in track.sources) {
    switch (source) {
      case BundledAudioSource(:final assetPath):
        return Ok(AssetAudio(assetPath));
      case LocalFileSource(:final fileReference):
        return Ok(FileAudio(fileReference));
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
