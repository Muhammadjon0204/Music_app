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

/// Audio shipped inside the app bundle (sample content). [assetPath] is
/// the asset key, e.g. `assets/demo_audio/tone_1.wav`.
final class BundledAudioSource extends TrackSource {
  const BundledAudioSource(this.assetPath);

  final String assetPath;

  @override
  bool operator ==(Object other) =>
      other is BundledAudioSource && other.assetPath == assetPath;

  @override
  int get hashCode => Object.hash(BundledAudioSource, assetPath);
}

/// Whether AURA itself may play a provider's track.
///
/// [unknown] is never treated as playable: it means "not checked yet".
enum StreamAvailability {
  unknown,

  /// The whole track streams through AURA's player.
  full,

  /// Only a short preview streams; the full track is elsewhere.
  previewOnly,

  /// No stream for AURA; the track can only be opened in the provider's
  /// own app or site.
  externalOnly,

  /// Removed, private, blocked or otherwise not playable anywhere.
  unavailable;

  bool get canStreamInApp => this == full || this == previewOnly;
}

/// A track in an online provider's catalog.
///
/// Holds no stream URL on purpose: provider URLs may be temporary or signed,
/// so they are resolved right before playback. [providerId] and
/// [externalId] identify the track; the other fields describe it as last
/// seen and may change.
final class ProviderTrackSource extends TrackSource {
  const ProviderTrackSource({
    required this.providerId,
    required this.externalId,
    this.availability = StreamAvailability.unknown,
    this.originalUrl,
    this.license,
  });

  final ProviderId providerId;
  final ExternalTrackId externalId;
  final StreamAvailability availability;

  /// The track's public page at the provider (attribution, "open in ...").
  final Uri? originalUrl;

  /// License as stated by the provider, e.g. "All rights reserved" or a
  /// Creative Commons name. Null when unknown.
  final String? license;

  bool get canOpenExternally => originalUrl != null;

  /// The app-wide ID for this provider track. Provider IDs contain no ":",
  /// so the same external ID at two providers gives two different IDs, and
  /// none collides with local IDs ("local-…").
  TrackId get trackId => TrackId('${providerId.value}:${externalId.value}');

  @override
  bool operator ==(Object other) =>
      other is ProviderTrackSource &&
      other.providerId == providerId &&
      other.externalId == externalId &&
      other.availability == availability &&
      other.originalUrl == originalUrl &&
      other.license == license;

  @override
  int get hashCode => Object.hash(
    ProviderTrackSource,
    providerId,
    externalId,
    availability,
    originalUrl,
    license,
  );
}

/// The provider and external ID behind an online track's app-wide ID
/// ("audius:D7KyD"), or null for local and bundled tracks. Lets the app
/// store only references to online tracks and look them up again.
(ProviderId, ExternalTrackId)? providerRefOf(TrackId id) {
  final colon = id.value.indexOf(':');
  if (colon <= 0 || colon == id.value.length - 1) return null;
  return (
    ProviderId(id.value.substring(0, colon)),
    ExternalTrackId(id.value.substring(colon + 1)),
  );
}
