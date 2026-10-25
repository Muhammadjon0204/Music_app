import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/providers/jamendo/jamendo_provider.dart';
import 'package:music_app/data/providers/jamendo/jamendo_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _answer(List<Object?> results) => {
  'headers': {'status': 'success', 'code': 0, 'results_count': results.length},
  'results': results,
};

/// A track as the API sends it (fields observed in October 2026).
Map<String, Object?> jamendoTrackJson({
  String id = '1214935',
  Object? name = 'Wish You Were Here',
  Object? duration = 270,
  Object? audio =
      'https://prod-1.storage.jamendo.com/?trackid=1214935'
      '&format=mp32&from=token',
}) => {
  'id': id,
  'name': name,
  'duration': duration,
  'artist_name': 'The.madpix.project',
  'album_name': 'Wish You Were Here',
  'license_ccurl': 'http://creativecommons.org/licenses/by-nc-sa/3.0/',
  'releasedate': '2015-03-29',
  'image': 'https://usercontent.jamendo.com?type=album&id=145774&width=300',
  'audio': audio,
  'shareurl': 'https://www.jamendo.com/track/$id',
};

void main() {
  late List<Uri> requests;
  late List<Map<String, Object?>> Function(Uri uri) answers;
  late JamendoProvider jamendo;
  late DateTime now;

  setUp(() {
    requests = [];
    answers = (_) => [_answer(const [])];
    now = DateTime(2026, 10, 25, 12);
    jamendo = JamendoProvider(
      clientId: 'test-client',
      now: () => now,
      http: JsonHttpClient(
        client: MockClient((request) async {
          final i = requests.where((u) => u == request.url).length;
          requests.add(request.url);
          final list = answers(request.url);
          return _json(list[i < list.length ? i : list.length - 1]);
        }),
        retryDelay: Duration.zero,
      ),
    );
  });

  List<Track> items(Result<ProviderPage<Track>> result) =>
      (result as Ok<ProviderPage<Track>>).value.items;

  group('mapper', () {
    test('maps a track with credit, backlink and license', () {
      final track = JamendoTrackMapper.fromJson(jamendoTrackJson())!;
      final source = track.sources.single as ProviderTrackSource;
      expect(track.id.value, 'jamendo:1214935');
      expect(track.title, 'Wish You Were Here');
      expect(track.artistName, 'The.madpix.project');
      expect(track.albumTitle, 'Wish You Were Here');
      expect(track.year, 2015);
      expect(track.duration, const Duration(seconds: 270));
      expect(track.artworkUri!.host, 'usercontent.jamendo.com');
      expect(source.availability, StreamAvailability.full);
      expect(
        source.originalUrl,
        Uri.parse('https://www.jamendo.com/track/1214935'),
      );
      expect(source.license, contains('by-nc-sa'));
    });

    test('accepts a duration sent as text', () {
      final track = JamendoTrackMapper.fromJson(
        jamendoTrackJson(duration: '95'),
      )!;
      expect(track.duration, const Duration(seconds: 95));
    });

    test('drops unusable entries, never invents metadata', () {
      expect(JamendoTrackMapper.fromJson(jamendoTrackJson(name: ' ')), isNull);
      expect(JamendoTrackMapper.fromJson(jamendoTrackJson(id: 'x1')), isNull);
      expect(JamendoTrackMapper.fromJson('nonsense'), isNull);
      final bare = JamendoTrackMapper.fromJson({'id': '7', 'name': 'Bare'})!;
      expect(bare.artistName, isNull);
      expect(bare.duration, isNull);
      expect(bare.artworkUri, isNull);
    });

    test('a track without an HTTPS stream is not playable here', () {
      final track = JamendoTrackMapper.fromJson(
        jamendoTrackJson(audio: 'http://insecure.example/a.mp3'),
      )!;
      expect(
        (track.sources.single as ProviderTrackSource).availability,
        StreamAvailability.unavailable,
      );
      expect(
        JamendoTrackMapper.listFromJson([
          jamendoTrackJson(id: '1', audio: null),
          jamendoTrackJson(id: '2'),
        ]).map((t) => t.id.value),
        ['jamendo:2'],
      );
    });

    test('a backlink must point to jamendo.com', () {
      final json = jamendoTrackJson()
        ..['shareurl'] = 'https://evil.example/track/1';
      final track = JamendoTrackMapper.fromJson(json)!;
      expect((track.sources.single as ProviderTrackSource).originalUrl, isNull);
    });
  });

  test('search calls the official endpoint with the client ID', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1'), jamendoTrackJson(id: '2')]),
    ];
    final result = await jamendo.searchTracks(
      ' ночной город ',
      page: const PageRequest(offset: 20, limit: 2),
    );

    final uri = requests.single;
    expect(uri.host, 'api.jamendo.com');
    expect(uri.path, '/v3.0/tracks/');
    expect(uri.queryParameters, {
      'search': 'ночной город',
      'limit': '2',
      'offset': '20',
      'client_id': 'test-client',
      'format': 'json',
      'audioformat': 'mp32',
    });
    expect(items(result), hasLength(2));
    expect((result as Ok<ProviderPage<Track>>).value.nextOffset, 22);
  });

  test('an empty query makes no request', () async {
    expect(items(await jamendo.searchTracks('  ')), isEmpty);
    expect(requests, isEmpty);
  });

  test(
    'a spurious empty answer is asked again, a bounded number of times',
    () async {
      answers = (_) => [
        _answer(const []),
        _answer([jamendoTrackJson(id: '1')]),
      ];
      final found = await jamendo.searchTracks('piano');
      expect(items(found), hasLength(1));
      expect(requests, hasLength(2));

      requests.clear();
      answers = (_) => [_answer(const [])];
      final nothing = await jamendo.searchTracks('zzzz');
      expect(items(nothing), isEmpty);
      expect(requests, hasLength(1 + JamendoProvider.emptyRetries));
    },
  );

  test('a cancelled search stops asking again', () async {
    final cancellation = Cancellation()..cancel();
    final result = await jamendo.searchTracks(
      'piano',
      cancellation: cancellation,
    );
    expect(result, isA<Err<ProviderPage<Track>>>());
    expect(requests.length, lessThanOrEqualTo(1));
  });

  test('popular uses this week\'s popularity', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1')]),
    ];
    final result = await jamendo.popularTracks();
    expect(requests.single.queryParameters['order'], 'popularity_week');
    expect(items(result), hasLength(1));
  });

  test('a rejected client ID is access denied, not "nothing found"', () async {
    answers = (_) => [
      {
        'headers': {
          'status': 'failed',
          'code': 5,
          'error_message': 'Invalid Client Id',
        },
        'results': <Object>[],
      },
    ];
    final result = await jamendo.searchTracks('x');
    expect((result as Err).failure, isA<AccessDeniedFailure>());
    expect(requests, hasLength(1));
  });

  test('an answer of the wrong shape is an invalid response', () async {
    answers = (_) => [
      {'unexpected': true},
    ];
    final result = await jamendo.popularTracks();
    expect((result as Err).failure, isA<InvalidResponseFailure>());
  });

  test('looks many tracks up in one request', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1'), jamendoTrackJson(id: '2')]),
    ];
    final result = await jamendo.tracksByIds(const [
      ExternalTrackId('1'),
      ExternalTrackId('2'),
      ExternalTrackId('1'),
      ExternalTrackId('bad id'),
    ]);
    expect(requests.single.queryParameters['id'], '1 2');
    expect((result as Ok<List<Track>>).value, hasLength(2));
  });

  test('details of an unknown track are not found', () async {
    final result = await jamendo.trackDetails(const ExternalTrackId('9'));
    expect((result as Err).failure, isA<NotFoundFailure>());
  });

  test('the stream is the audio URL of a fresh lookup', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1214935')]),
    ];
    final result = await jamendo.streamUri(const ExternalTrackId('1214935'));
    final uri = (result as Ok<Uri>).value;
    expect(uri.host, 'prod-1.storage.jamendo.com');
    expect(uri.queryParameters['trackid'], '1214935');
    expect(requests.single.queryParameters['id'], '1214935');
  });

  test('no stream for an invalid ID, without a request', () async {
    final result = await jamendo.streamUri(const ExternalTrackId('../x'));
    expect((result as Err).failure, isA<NotFoundFailure>());
    expect(requests, isEmpty);
  });

  test('requires credit next to its tracks', () {
    expect(jamendo, isA<AttributionRequiredProvider>());
    expect(jamendo.displayName, 'Jamendo');
  });

  test('a stream seen in search plays without asking again', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1214935')]),
    ];
    await jamendo.searchTracks('wish');
    requests.clear();

    final result = await jamendo.streamUri(const ExternalTrackId('1214935'));
    expect((result as Ok<Uri>).value.host, 'prod-1.storage.jamendo.com');
    expect(requests, isEmpty);
    // Asked again (e.g. prefetch, then play): still from memory.
    await jamendo.streamUri(const ExternalTrackId('1214935'));
    expect(requests, isEmpty);
  });

  test('a remembered stream expires', () async {
    answers = (_) => [
      _answer([jamendoTrackJson(id: '1214935')]),
    ];
    await jamendo.searchTracks('wish');
    requests.clear();
    now = now.add(JamendoProvider.streamUrlTtl);

    await jamendo.streamUri(const ExternalTrackId('1214935'));
    expect(requests.single.queryParameters['id'], '1214935');
  });
}
