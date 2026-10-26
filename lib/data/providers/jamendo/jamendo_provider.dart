import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/providers/jamendo/jamendo_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/domain/providers/radio_mix.dart';

/// Jamendo through its official API v3 (https://developer.jamendo.com/v3.0).
///
/// Creative Commons music, read-only with the app's public client ID (no
/// secret; the client secret is only for OAuth, which the app does not
/// use). The API terms allow non-commercial use, require crediting
/// Jamendo with a backlink to each track's page, and forbid offline
/// caching, so nothing from Jamendo is written to disk here.
final class JamendoProvider
    implements
        SearchableProvider,
        PopularTracksProvider,
        TrackDetailsProvider,
        BatchTrackDetailsProvider,
        StreamingProvider,
        ArtistProvider,
        RadioProvider,
        AttributionRequiredProvider {
  JamendoProvider({
    required this._http,
    required this.clientId,
    Uri? apiBase,
    DateTime Function()? now,
  }) : _apiBase = apiBase ?? Uri.parse('https://api.jamendo.com/v3.0'),
       _now = now ?? DateTime.now;

  /// Largest page the API accepts.
  static const maxPageSize = 200;

  /// Largest number of IDs sent in one lookup (keeps URLs short).
  static const maxBatch = 50;

  /// The API sometimes answers a valid request with an empty success (seen
  /// in about half of identical requests in October 2026). An empty answer
  /// is asked again this many times before it is believed. Once is enough
  /// to catch most of them without making a real "nothing found" slow.
  static const emptyRetries = 1;

  /// How long a stream URL seen in a search or list answer is used instead
  /// of asking the API again when the track is played.
  static const streamUrlTtl = Duration(minutes: 5);
  static const _maxStreamUrls = 500;

  final JsonHttpClient _http;
  final Uri _apiBase;
  final String clientId;
  final DateTime Function() _now;

  /// Stream URLs from recent answers, in memory only.
  final _streamUrls = <String, (Uri, DateTime)>{};

  @override
  ProviderId get id => JamendoTrackMapper.providerId;

  @override
  String get displayName => 'Jamendo';

  @override
  Future<Result<ProviderPage<Track>>> searchTracks(
    String query, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return Ok(ProviderPage(items: const []));
    return _page({'search': text}, page, cancellation);
  }

  @override
  Future<Result<ProviderPage<Track>>> popularTracks({
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) => _page(const {'order': 'popularity_week'}, page, cancellation);

  @override
  Future<Result<Track>> trackDetails(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) async {
    final result = await tracksByIds([id], cancellation: cancellation);
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.isEmpty => const Err(
        NotFoundFailure(debugMessage: 'Jamendo track not found'),
      ),
      Ok(:final value) => Ok(value.first),
    };
  }

  /// `id=1+2+3`; IDs the API no longer knows are absent.
  @override
  Future<Result<List<Track>>> tracksByIds(
    List<ExternalTrackId> ids, {
    Cancellation? cancellation,
  }) async {
    final valid = [
      for (final id in ids.toSet())
        if (JamendoTrackMapper.isValidId(id.value)) id.value,
    ];
    final found = <Track>[];
    for (var start = 0; start < valid.length; start += maxBatch) {
      final chunk = valid.skip(start).take(maxBatch).toList();
      final response = await _results({
        'id': chunk.join(' '),
        'limit': '${chunk.length}',
      }, cancellation);
      switch (response) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          // Unplayable tracks are kept: a saved one that became
          // unavailable is shown as such, not silently dropped.
          for (final item in value) {
            if (JamendoTrackMapper.fromJson(item) case final track?) {
              found.add(track);
            }
          }
      }
    }
    return Ok(found);
  }

  /// The `audio` URL from a recent answer (search, popular, lookup), or of
  /// a fresh lookup. It carries a token, so it is kept only in memory and
  /// only for [streamUrlTtl].
  @override
  Future<Result<Uri>> streamUri(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) async {
    if (!JamendoTrackMapper.isValidId(id.value)) {
      return const Err(NotFoundFailure(debugMessage: 'Invalid Jamendo ID'));
    }
    if (_streamUrls[id.value] case (final uri, final seenAt)
        when _now().difference(seenAt) < streamUrlTtl) {
      return Ok(uri);
    }
    final response = await _results({'id': id.value}, cancellation);
    switch (response) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final json = value.firstOrNull;
        final uri = json is Map<String, Object?>
            ? JamendoTrackMapper.streamUriOf(json)
            : null;
        return uri != null
            ? Ok(uri)
            : const Err(NotFoundFailure(debugMessage: 'No Jamendo stream'));
    }
  }

  @override
  Future<Result<OnlineArtist>> artist(
    ExternalArtistId id, {
    Cancellation? cancellation,
  }) async {
    if (!JamendoTrackMapper.isValidId(id.value)) {
      return const Err(NotFoundFailure(debugMessage: 'Invalid Jamendo artist'));
    }
    final response = await _results(
      {'id': id.value},
      cancellation,
      endpoint: 'artists',
    );
    return switch (response) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => switch (JamendoTrackMapper.artistFromJson(
        value.firstOrNull,
      )) {
        final artist? => Ok(artist),
        null => const Err(
          NotFoundFailure(debugMessage: 'Jamendo artist not found'),
        ),
      },
    };
  }

  /// The artist's tracks, most popular of all time first.
  @override
  Future<Result<ProviderPage<Track>>> artistTracks(
    ExternalArtistId id, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) async {
    if (!JamendoTrackMapper.isValidId(id.value)) {
      return const Err(NotFoundFailure(debugMessage: 'Invalid Jamendo artist'));
    }
    return _page(
      {'artist_id': id.value, 'order': 'popularity_total'},
      page,
      cancellation,
    );
  }

  /// Popular tracks with the seed's genre tags, mixed with a few more by
  /// the same artist. (The API's "similar" endpoint answered empty in
  /// October 2026.)
  @override
  Future<Result<List<Track>>> radioFor(
    Track seed, {
    int limit = 30,
    Cancellation? cancellation,
  }) async {
    final source = seed.sources
        .whereType<ProviderTrackSource>()
        .where((s) => s.providerId == id)
        .firstOrNull;
    final genres = source?.genres ?? const <String>[];
    final artistId = source?.artistExternalId;
    final results = await Future.wait([
      _page(
        {
          if (genres.isNotEmpty) 'fuzzytags': genres.take(3).join(' '),
          'order': 'popularity_week',
        },
        PageRequest(limit: limit),
        cancellation,
      ),
      if (artistId != null)
        artistTracks(
          artistId,
          page: const PageRequest(limit: 6),
          cancellation: cancellation,
        ),
    ]);
    final failure = results
        .map((r) => r is Err<ProviderPage<Track>> ? r.failure : null)
        .nonNulls
        .firstOrNull;
    final lists = [
      for (final result in results)
        if (result case Ok(:final value)) value.items,
    ];
    if (lists.isEmpty) {
      return Err(failure ?? const UnexpectedFailure(debugMessage: 'No radio'));
    }
    return Ok(mixForRadio(lists, seed: seed, limit: limit));
  }

  Future<Result<ProviderPage<Track>>> _page(
    Map<String, String> query,
    PageRequest page,
    Cancellation? cancellation,
  ) async {
    final limit = page.limit.clamp(1, maxPageSize);
    final response = await _results({
      ...query,
      'limit': '$limit',
      'offset': '${page.offset}',
    }, cancellation);
    return switch (response) {
      Err(:final failure) => Err(failure),
      // A full page suggests more; counted before unusable entries are
      // dropped, so filtering never ends paging early.
      Ok(:final value) => Ok(
        ProviderPage(
          items: JamendoTrackMapper.listFromJson(value),
          nextOffset: value.length >= limit ? page.offset + limit : null,
        ),
      ),
    };
  }

  /// The `results` of `/tracks/` (or another [endpoint]) for [query],
  /// asked again when empty (see [emptyRetries]). Track answers include
  /// `musicinfo` for genres.
  Future<Result<List<Object?>>> _results(
    Map<String, String> query,
    Cancellation? cancellation, {
    String endpoint = 'tracks',
  }) async {
    final uri = _apiBase.replace(
      pathSegments: [..._apiBase.pathSegments, endpoint, ''],
      queryParameters: {
        ...query,
        'client_id': clientId,
        'format': 'json',
        if (endpoint == 'tracks') ...{
          'audioformat': 'mp32',
          'include': 'musicinfo',
        },
      },
    );
    for (var attempt = 0; ; attempt++) {
      final results = switch (await _http.getJson(
        uri,
        cancellation: cancellation,
      )) {
        Err(:final failure) => Err<List<Object?>>(failure),
        Ok(:final value) => _parse(value),
      };
      if (results case Ok(:final value)) _rememberStreams(value);
      if (results case Ok(:final value)
          when value.isEmpty && attempt < emptyRetries) {
        if (cancellation?.isCancelled ?? false) {
          return const Err(CancelledFailure());
        }
        continue;
      }
      return results;
    }
  }

  void _rememberStreams(List<Object?> items) {
    final now = _now();
    for (final item in items) {
      if (item is! Map<String, Object?>) continue;
      final id = item['id'];
      final uri = JamendoTrackMapper.streamUriOf(item);
      if (id is String && uri != null) _streamUrls[id] = (uri, now);
    }
    while (_streamUrls.length > _maxStreamUrls) {
      _streamUrls.remove(_streamUrls.keys.first);
    }
  }

  /// Jamendo reports errors inside a 200 answer: `headers.status` is
  /// "failed" with a numeric `code` (5 = client ID not accepted).
  static Result<List<Object?>> _parse(Object? body) {
    if (body is! Map<String, Object?>) {
      return const Err(InvalidResponseFailure(debugMessage: 'Not an object'));
    }
    final headers = body['headers'];
    final results = body['results'];
    if (headers is! Map<String, Object?> || results is! List<Object?>) {
      return const Err(
        InvalidResponseFailure(debugMessage: 'Jamendo answer without results'),
      );
    }
    if (headers['status'] != 'success') {
      final code = headers['code'];
      return Err(
        code == 5
            ? const AccessDeniedFailure(
                debugMessage: 'Jamendo client ID not accepted',
              )
            : InvalidResponseFailure(debugMessage: 'Jamendo error $code'),
      );
    }
    return Ok(results);
  }
}
