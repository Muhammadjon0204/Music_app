import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Converts Jamendo API v3 track JSON into the app's [Track].
///
/// Defensive like the other mappers: missing metadata stays null, a track
/// without an ID or name is dropped. The `audio` URL in responses is not
/// kept: playback asks the API for a fresh one.
abstract final class JamendoTrackMapper {
  static const providerId = ProviderId('jamendo');

  /// Null when [json] is not a usable track.
  static Track? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = _text(json['id']);
    final title = _text(json['name']);
    if (id == null || !isValidId(id) || title == null) return null;

    final source = ProviderTrackSource(
      providerId: providerId,
      externalId: ExternalTrackId(id),
      availability: streamUriOf(json) != null
          ? StreamAvailability.full
          : StreamAvailability.unavailable,
      originalUrl: _pageUrl(json['shareurl']),
      license: _text(json['license_ccurl']),
      artistExternalId: switch (_text(json['artist_id'])) {
        final id? when isValidId(id) => ExternalArtistId(id),
        _ => null,
      },
      genres: genresOf(json),
    );
    final duration = _seconds(json['duration']);
    return Track(
      id: source.trackId,
      title: title,
      artistName: _text(json['artist_name']),
      albumTitle: _text(json['album_name']),
      year: _year(json['releasedate']),
      duration: duration != null && duration > 0
          ? Duration(seconds: duration)
          : null,
      artworkUri: _https(json['image']) ?? _https(json['album_image']),
      sources: [source],
    );
  }

  /// Playable tracks from a list response.
  static List<Track> listFromJson(Object? data) => [
    if (data is List<Object?>)
      for (final item in data)
        if (fromJson(item) case final track?
            when (track.sources.single as ProviderTrackSource).availability !=
                StreamAvailability.unavailable)
          track,
  ];

  /// Jamendo track IDs are decimal numbers.
  static bool isValidId(String id) =>
      id.isNotEmpty && id.length <= 20 && RegExp(r'^[0-9]+$').hasMatch(id);

  /// The track's stream (`audio`), HTTPS only.
  static Uri? streamUriOf(Map<String, Object?> json) => _https(json['audio']);

  /// A Jamendo artist (`/artists/`); null without an ID and a name.
  static OnlineArtist? artistFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = _text(json['id']);
    final name = _text(json['name']);
    if (id == null || !isValidId(id) || name == null) return null;
    return OnlineArtist(
      providerId: providerId,
      id: ExternalArtistId(id),
      name: name,
      imageUri: _https(json['image']),
      pageUrl: _pageUrl(json['shareurl']),
    );
  }

  /// `musicinfo.tags.genres` (present with `include=musicinfo`).
  static List<String> genresOf(Map<String, Object?> json) {
    final info = json['musicinfo'];
    final tags = info is Map<String, Object?> ? info['tags'] : null;
    final genres = tags is Map<String, Object?> ? tags['genres'] : null;
    return [
      if (genres is List<Object?>)
        for (final g in genres)
          if (g is String && g.trim().isNotEmpty) g.trim(),
    ];
  }

  static String? _text(Object? value) => switch (value) {
    final String s when s.trim().isNotEmpty => s.trim(),
    final int n => '$n',
    _ => null,
  };

  static int? _seconds(Object? value) => switch (value) {
    final int n => n,
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  static Uri? _https(Object? url) {
    if (url is! String) return null;
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.isScheme('https') && uri.host.isNotEmpty
        ? uri
        : null;
  }

  /// The track's page on jamendo.com, the backlink the API terms require.
  static Uri? _pageUrl(Object? url) {
    final uri = _https(url);
    if (uri == null) return null;
    return uri.host == 'jamendo.com' || uri.host == 'www.jamendo.com'
        ? uri
        : null;
  }

  static int? _year(Object? date) =>
      date is String ? DateTime.tryParse(date)?.year : null;
}
