import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

/// Database form of a [Track] (schema version 1).
abstract final class TrackRecord {
  static Map<String, Object?> toMap(Track track) => {
    'title': track.title,
    'artist': track.artistName,
    'album': track.albumTitle,
    'albumArtist': track.albumArtist,
    'trackNumber': track.trackNumber,
    'discNumber': track.discNumber,
    'year': track.year,
    'durationMs': track.duration?.inMilliseconds,
    'artwork': track.artworkUri?.toString(),
    'addedAt': track.addedAt?.millisecondsSinceEpoch,
    'sources': [for (final source in track.sources) _sourceToMap(source)],
  };

  /// Null when the record is unusable (e.g. written by a broken build).
  static Track? fromMap(String id, Map<String, Object?> map) {
    try {
      final sources = [
        for (final raw in (map['sources'] as List<Object?>? ?? const []))
          if (raw is Map<String, Object?>) ?_sourceFromMap(raw),
      ];
      final title = map['title'];
      if (title is! String || title.trim().isEmpty || sources.isEmpty) {
        return null;
      }
      final durationMs = map['durationMs'];
      final addedAt = map['addedAt'];
      final artwork = map['artwork'];
      return Track(
        id: TrackId(id),
        title: title,
        sources: sources,
        artistName: map['artist'] as String?,
        albumTitle: map['album'] as String?,
        albumArtist: map['albumArtist'] as String?,
        trackNumber: map['trackNumber'] as int?,
        discNumber: map['discNumber'] as int?,
        year: map['year'] as int?,
        duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
        artworkUri: artwork is String ? Uri.tryParse(artwork) : null,
        addedAt: addedAt is int
            ? DateTime.fromMillisecondsSinceEpoch(addedAt)
            : null,
      );
    } on Object {
      // Unexpected field types: skip the record rather than fail the load.
      return null;
    }
  }

  static Map<String, Object?> _sourceToMap(TrackSource source) =>
      switch (source) {
        LocalFileSource(:final fileReference) => {
          'type': 'local',
          'ref': fileReference,
        },
        BundledAudioSource(:final assetPath) => {
          'type': 'bundled',
          'ref': assetPath,
        },
        ProviderTrackSource(:final providerId, :final externalId) => {
          'type': 'provider',
          'provider': providerId.value,
          'ref': externalId.value,
        },
      };

  static TrackSource? _sourceFromMap(Map<String, Object?> map) {
    final ref = map['ref'];
    if (ref is! String || ref.isEmpty) return null;
    return switch (map['type']) {
      'local' => LocalFileSource(ref),
      'bundled' => BundledAudioSource(ref),
      'provider' when map['provider'] is String => ProviderTrackSource(
        providerId: ProviderId(map['provider']! as String),
        externalId: ExternalTrackId(ref),
      ),
      _ => null,
    };
  }
}
