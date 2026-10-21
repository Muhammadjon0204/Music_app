// IDs owned by AURA's own library. A provider's catalog ID never goes here;
// it lives in ProviderTrackSource as an ExternalTrackId.
extension type const TrackId(String value) {}

extension type const AlbumId(String value) {}

extension type const ArtistId(String value) {}

extension type const PlaylistId(String value) {}

/// Identifies an online music provider integration.
extension type const ProviderId(String value) {}

/// A track's ID inside one provider's catalog. Meaningful only together with
/// its [ProviderId].
extension type const ExternalTrackId(String value) {}
