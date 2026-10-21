import 'package:music_app/domain/music/ids.dart';

/// Where a track can be played from. One recording may have several sources.
sealed class TrackSource {
  const TrackSource();
}

/// A file the user imported.
///
/// [fileReference] is an opaque handle owned by the data layer (for example a
/// path inside the app container). The domain never interprets it.
final class LocalFileSource extends TrackSource {
  const LocalFileSource(this.fileReference);

  final String fileReference;

  @override
  bool operator ==(Object other) =>
      other is LocalFileSource && other.fileReference == fileReference;

  @override
  int get hashCode => Object.hash(LocalFileSource, fileReference);
}

/// A track in an online provider's catalog.
///
/// Holds no stream URL on purpose: provider URLs may be temporary or signed,
/// so they are resolved right before playback.
final class ProviderTrackSource extends TrackSource {
  const ProviderTrackSource({
    required this.providerId,
    required this.externalId,
  });

  final ProviderId providerId;
  final ExternalTrackId externalId;

  @override
  bool operator ==(Object other) =>
      other is ProviderTrackSource &&
      other.providerId == providerId &&
      other.externalId == externalId;

  @override
  int get hashCode => Object.hash(ProviderTrackSource, providerId, externalId);
}
