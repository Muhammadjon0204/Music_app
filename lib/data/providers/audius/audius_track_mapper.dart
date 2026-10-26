import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Converts Audius API track JSON into AURA's [Track].
///
/// Defensive: any field may be missing or of an unexpected type; missing
/// metadata stays null (never invented). A track without an ID or title is
/// dropped. The signed `stream.url` in responses is deliberately ignored:
/// it expires, and playback always resolves a fresh one.
abstract final class AudiusTrackMapper {
  static const providerId = ProviderId('audius');
  static const _site = 'https://audius.co';

  /// Null when [json] is not a usable track.
  static Track? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final title = json['title'];
    if (id is! String || !isValidId(id)) return null;
    if (title is! String || title.trim().isEmpty) return null;

    final user = json['user'];
    final userMap = user is Map<String, Object?>
        ? user
        : const <String, Object?>{};
    final artist = _text(userMap['name']) ?? _text(userMap['handle']);
    final duration = json['duration'];
    final artwork = _artwork(json['artwork']);

    final source = ProviderTrackSource(
      providerId: providerId,
      externalId: ExternalTrackId(id),
      availability: availabilityOf(json),
      originalUrl: _pageUrl(json['permalink']),
      license: _text(json['license']),
      artistExternalId: switch (_text(userMap['id'])) {
        final id? when isValidId(id) => ExternalArtistId(id),
        _ => null,
      },
      genres: [?_text(json['genre'])],
    );
    return Track(
      id: source.trackId,
      title: title.trim(),
      artistName: artist,
      year: _year(json['release_date']),
      duration: duration is int && duration > 0
          ? Duration(seconds: duration)
          : null,
      artworkUri: artwork,
      artworkAlternatives: _mirrors(artwork, json['artwork']),
      sources: [source],
    );
  }

  /// Usable tracks from a list response; unplayable-anywhere ones are left
  /// out so lists do not fill with dead entries.
  static List<Track> listFromJson(Object? data) => [
    if (data is List<Object?>)
      for (final item in data)
        if (fromJson(item) case final track?
            when _availability(track) != StreamAvailability.unavailable)
          track,
  ];

  /// Audius IDs are short base62-like strings (e.g. "D7KyD").
  static bool isValidId(String id) =>
      id.isNotEmpty &&
      id.length <= 32 &&
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(id);

  /// What AURA may do with the track, from the API's own flags:
  /// - deleted, unavailable, or the artist's account deactivated →
  ///   unavailable;
  /// - streamable for this caller (`access.stream`) → full;
  /// - gated (follow/purchase on Audius) → externalOnly;
  /// - marked not streamable → unavailable (its stream returns 404).
  static StreamAvailability availabilityOf(Map<String, Object?> json) {
    final user = json['user'];
    final deactivated =
        user is Map<String, Object?> && user['is_deactivated'] == true;
    if (json['is_delete'] == true ||
        json['is_available'] == false ||
        deactivated) {
      return StreamAvailability.unavailable;
    }
    if (json['is_streamable'] == false) return StreamAvailability.unavailable;
    final access = json['access'];
    final canStream =
        access is Map<String, Object?> && access['stream'] == true;
    if (canStream) return StreamAvailability.full;
    if (json['stream_conditions'] != null || json['is_stream_gated'] == true) {
      return StreamAvailability.externalOnly;
    }
    return StreamAvailability.unknown;
  }

  static StreamAvailability _availability(Track track) =>
      (track.sources.single as ProviderTrackSource).availability;

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// `/handle/slug` → https://audius.co/handle/slug. Anything else (absolute
  /// URLs, other hosts) is refused.
  static Uri? _pageUrl(Object? permalink) {
    if (permalink is! String || !permalink.startsWith('/')) return null;
    if (permalink.startsWith('//')) return null;
    final uri = Uri.tryParse('$_site$permalink');
    return uri != null && uri.host == 'audius.co' ? uri : null;
  }

  /// An Audius user (`/v1/users/{id}`) as an artist; null without an ID
  /// and a name.
  static OnlineArtist? artistFromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = _text(json['id']);
    final name = _text(json['name']) ?? _text(json['handle']);
    if (id == null || !isValidId(id) || name == null) return null;
    final handle = _text(json['handle']);
    final followers = json['follower_count'];
    final tracks = json['track_count'];
    return OnlineArtist(
      providerId: providerId,
      id: ExternalArtistId(id),
      name: name,
      imageUri: _artwork(json['profile_picture']),
      coverUri: _artwork(json['cover_photo'], sizes: const ['640x', '2000x']),
      followerCount: followers is int && followers >= 0 ? followers : null,
      trackCount: tracks is int && tracks >= 0 ? tracks : null,
      bio: _text(json['bio']),
      pageUrl: handle != null && RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(handle)
          ? Uri.parse('$_site/$handle')
          : null,
    );
  }

  /// The 480×480 cover: sharp in lists and on the lock screen, small enough
  /// for mobile data. HTTPS only.
  static Uri? _artwork(
    Object? artwork, {
    List<String> sizes = const ['480x480', '1000x1000', '150x150'],
  }) {
    if (artwork is! Map<String, Object?>) return null;
    final url = sizes.map((size) => artwork[size]).nonNulls.firstOrNull;
    if (url is! String) return null;
    final uri = Uri.tryParse(url);
    return uri != null && uri.isScheme('https') && uri.hasAuthority
        ? uri
        : null;
  }

  /// [artwork] on each mirror host, as the Audius image guide prescribes:
  /// same path, other node. HTTPS only, at most a few.
  static List<Uri> _mirrors(Uri? artwork, Object? json) {
    if (artwork == null || json is! Map<String, Object?>) return const [];
    final mirrors = json['mirrors'];
    if (mirrors is! List<Object?>) return const [];
    return [
      for (final mirror in mirrors)
        if (mirror is String)
          if (Uri.tryParse(mirror) case final host?
              when host.isScheme('https') &&
                  host.host.isNotEmpty &&
                  host.host != artwork.host)
            artwork.replace(
              host: host.host,
              port: host.hasPort ? host.port : null,
            ),
    ].take(_maxMirrors).toList();
  }

  static const _maxMirrors = 3;

  static int? _year(Object? date) {
    if (date is! String) return null;
    return DateTime.tryParse(date)?.year;
  }
}
