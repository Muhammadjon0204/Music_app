import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/providers/audius/audius_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Audius through its official public REST API (https://docs.audius.co/api).
///
/// Read-only and without an API key: requests identify the app with the
/// public `app_name` parameter, which the docs allow for read access. No
/// secret is involved. The free plan allows 10 requests/s; the app makes a
/// handful per screen.
///
/// The API Terms allow only session-based caching, so nothing from Audius
/// is written to disk here.
final class AudiusProvider
    implements
        SearchableProvider,
        PopularTracksProvider,
        TrackDetailsProvider,
        BatchTrackDetailsProvider,
        StreamingProvider {
  AudiusProvider({required this._http, this.appName = 'MusicLab', Uri? apiBase})
    : _apiBase = apiBase ?? Uri.parse('https://api.audius.co/v1');

  /// Largest page the API accepts.
  static const maxPageSize = 100;

  final JsonHttpClient _http;
  final Uri _apiBase;
  final String appName;

  @override
  ProviderId get id => AudiusTrackMapper.providerId;

  @override
  String get displayName => 'Audius';

  @override
  Future<Result<ProviderPage<Track>>> searchTracks(
    String query, {
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) async {
    final text = query.trim();
    if (text.isEmpty) return Ok(ProviderPage(items: const []));
    return _page(['tracks', 'search'], {'query': text}, page, cancellation);
  }

  @override
  Future<Result<ProviderPage<Track>>> popularTracks({
    PageRequest page = const PageRequest(),
    Cancellation? cancellation,
  }) => _page(['tracks', 'trending'], const {}, page, cancellation);

  @override
  Future<Result<Track>> trackDetails(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) async {
    // The API answers malformed IDs with 400; treat them as not found.
    if (!AudiusTrackMapper.isValidId(id.value)) {
      return const Err(NotFoundFailure(debugMessage: 'Invalid Audius ID'));
    }
    final response = await _http.getJson(
      _uri(['tracks', id.value]),
      cancellation: cancellation,
    );
    return switch (response) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => switch (AudiusTrackMapper.fromJson(_data(value))) {
        final track? => Ok(track),
        null => const Err(
          InvalidResponseFailure(debugMessage: 'Audius track without data'),
        ),
      },
    };
  }

  /// Largest number of IDs sent in one bulk request (keeps URLs short).
  static const maxBatch = 50;

  /// Many tracks per request (`/v1/tracks?id=...&id=...`). Used to show
  /// saved references again; IDs the API no longer knows are absent.
  @override
  Future<Result<List<Track>>> tracksByIds(
    List<ExternalTrackId> ids, {
    Cancellation? cancellation,
  }) async {
    final valid = [
      for (final id in ids.toSet())
        if (AudiusTrackMapper.isValidId(id.value)) id.value,
    ];
    final found = <Track>[];
    for (var start = 0; start < valid.length; start += maxBatch) {
      final chunk = valid.skip(start).take(maxBatch).toList();
      final response = await _http.getJson(
        _apiBase.replace(
          pathSegments: [..._apiBase.pathSegments, 'tracks'],
          queryParameters: {'id': chunk, 'app_name': appName},
        ),
        cancellation: cancellation,
      );
      switch (response) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final data = _data(value);
          if (data is! List<Object?>) {
            return const Err(
              InvalidResponseFailure(debugMessage: 'Audius bulk without data'),
            );
          }
          // Keeps unplayable entries: a saved track that became
          // unavailable is shown as such, not silently dropped.
          for (final item in data) {
            if (AudiusTrackMapper.fromJson(item) case final track?) {
              found.add(track);
            }
          }
      }
    }
    return Ok(found);
  }

  /// The API's stream endpoint. It redirects to a short-lived signed URL on
  /// a content node, which the audio engine follows; so no request is made
  /// here and nothing expiring is ever kept.
  @override
  Future<Result<Uri>> streamUri(
    ExternalTrackId id, {
    Cancellation? cancellation,
  }) async {
    if (!AudiusTrackMapper.isValidId(id.value)) {
      return const Err(NotFoundFailure(debugMessage: 'Invalid Audius ID'));
    }
    return Ok(_uri(['tracks', id.value, 'stream']));
  }

  Future<Result<ProviderPage<Track>>> _page(
    List<String> path,
    Map<String, String> query,
    PageRequest page,
    Cancellation? cancellation,
  ) async {
    final limit = page.limit.clamp(1, maxPageSize);
    final response = await _http.getJson(
      _uri(path, {...query, 'limit': '$limit', 'offset': '${page.offset}'}),
      cancellation: cancellation,
    );
    switch (response) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final data = _data(value);
        if (data is! List<Object?>) {
          return const Err(
            InvalidResponseFailure(debugMessage: 'Audius list without data'),
          );
        }
        // A full page suggests more; counted before unusable entries are
        // dropped, so filtering never ends paging early.
        return Ok(
          ProviderPage(
            items: AudiusTrackMapper.listFromJson(data),
            nextOffset: data.length >= limit ? page.offset + limit : null,
          ),
        );
    }
  }

  Uri _uri(List<String> path, [Map<String, String> query = const {}]) =>
      _apiBase.replace(
        pathSegments: [..._apiBase.pathSegments, ...path],
        queryParameters: {...query, 'app_name': appName},
      );

  static Object? _data(Object? body) =>
      body is Map<String, Object?> ? body['data'] : null;
}
