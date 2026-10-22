import 'dart:async';

import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Turns a track into something the engine can open. May need the network
/// (online providers), so it is asynchronous; [cancellation] fires when the
/// result is no longer wanted (the user switched tracks).
typedef AudioResolver = Future<Result<AudioLocation>> Function(
  Track track,
  Cancellation cancellation,
);

/// The app's [AudioResolver]: local sources directly, online sources through
/// the registered [StreamingProvider]s. Sources are tried in the track's
/// order; when none works, the first failure explains why.
final class TrackAudioResolver {
  TrackAudioResolver({
    this._resolveFile,
    this._fileExists,
    ProviderRegistry? providers,
  }) : _providers = providers ?? ProviderRegistry.empty;

  final String? Function(String reference)? _resolveFile;
  final bool Function(String path)? _fileExists;
  final ProviderRegistry _providers;

  Future<Result<AudioLocation>> call(
    Track track,
    Cancellation cancellation,
  ) async {
    AppFailure? firstFailure;
    for (final source in track.sources) {
      if (cancellation.isCancelled) return const Err(CancelledFailure());
      final Result<AudioLocation>? result = switch (source) {
        LocalFileSource() || BundledAudioSource() => _resolveLocalSource(
          source,
          track,
          resolveFile: _resolveFile,
          fileExists: _fileExists,
        ),
        ProviderTrackSource() => await _resolveProvider(source, cancellation),
      };
      switch (result) {
        case Ok():
          return result;
        case Err(:final failure):
          if (failure is CancelledFailure) return result;
          firstFailure ??= failure;
        case null:
          break;
      }
    }
    return Err(
      firstFailure ??
          UnsupportedMediaFailure(
            debugMessage: 'No playable source for track ${track.id.value}',
          ),
    );
  }

  Future<Result<AudioLocation>> _resolveProvider(
    ProviderTrackSource source,
    Cancellation cancellation,
  ) async {
    // Known not to stream: say why without asking the network.
    switch (source.availability) {
      case StreamAvailability.externalOnly:
        return Err(
          FeatureUnavailableFailure(
            debugMessage: '${source.trackId.value} opens only externally',
          ),
        );
      case StreamAvailability.unavailable:
        return Err(
          AccessDeniedFailure(
            debugMessage: '${source.trackId.value} is unavailable',
          ),
        );
      case StreamAvailability.full ||
          StreamAvailability.previewOnly ||
          StreamAvailability.unknown:
        break;
    }

    final provider = _providers.capability<StreamingProvider>(
      source.providerId,
    );
    final Result<Uri> uri;
    switch (provider) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        uri = await value.streamUri(
          source.externalId,
          cancellation: cancellation,
        );
    }
    if (cancellation.isCancelled) return const Err(CancelledFailure());
    return switch (uri) {
      Ok(:final value) when value.isScheme('https') => Ok(StreamAudio(value)),
      Ok() => Err(
        InvalidResponseFailure(
          debugMessage: 'Non-HTTPS stream for ${source.trackId.value}',
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}

/// Picks the first local source of [track] (bundled asset or imported
/// file). Online sources are skipped: they need [TrackAudioResolver].
///
/// [resolveFile] turns a stored file reference (e.g. `library:audio/x.mp3`)
/// into an absolute path; [fileExists] lets a missing file be reported
/// precisely instead of as a decoding error.
Result<AudioLocation> resolveTrackAudio(
  Track track, {
  String? Function(String reference)? resolveFile,
  bool Function(String path)? fileExists,
}) {
  for (final source in track.sources) {
    final result = _resolveLocalSource(
      source,
      track,
      resolveFile: resolveFile,
      fileExists: fileExists,
    );
    if (result != null) return result;
  }
  return Err(
    UnsupportedMediaFailure(
      debugMessage: 'No playable source for track ${track.id.value}',
    ),
  );
}

/// Null for sources that are not local.
Result<AudioLocation>? _resolveLocalSource(
  TrackSource source,
  Track track, {
  String? Function(String reference)? resolveFile,
  bool Function(String path)? fileExists,
}) {
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
          FileAccessFailure(debugMessage: 'Missing file for ${track.id.value}'),
        );
      }
      return Ok(FileAudio(path));
    case ProviderTrackSource():
      return null;
  }
}
