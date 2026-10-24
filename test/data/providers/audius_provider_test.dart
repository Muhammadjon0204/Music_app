import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/audio/audio_engine.dart';
import 'package:music_app/audio/track_audio_resolver.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/providers/audius/audius_provider.dart';
import 'package:music_app/data/providers/audius/audius_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../../helpers/audius_fixtures.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late List<Uri> requests;
  late http.Response Function(http.Request request) respond;
  late AudiusProvider audius;

  setUp(() {
    requests = [];
    respond = (_) => _json({'data': <Object>[]});
    audius = AudiusProvider(
      http: JsonHttpClient(
        client: MockClient((request) async {
          requests.add(request.url);
          return respond(request);
        }),
        retryDelay: Duration.zero,
      ),
    );
  });

  List<Track> items(Result<ProviderPage<Track>> result) =>
      (result as Ok<ProviderPage<Track>>).value.items;

  test(
    'search calls the official endpoint with app_name, no secrets',
    () async {
      respond = (_) => _json({
        'data': [audiusTrackJson(id: 'a1'), audiusTrackJson(id: 'a2')],
      });
      final result = await audius.searchTracks(
        ' ночной город ',
        page: const PageRequest(offset: 20, limit: 10),
      );

      final uri = requests.single;
      expect(uri.host, 'api.audius.co');
      expect(uri.path, '/v1/tracks/search');
      expect(uri.queryParameters, {
        'query': 'ночной город',
        'limit': '10',
        'offset': '20',
        'app_name': 'MusicLab',
      });
      expect(items(result).map((t) => t.id.value), ['audius:a1', 'audius:a2']);
    },
  );

  test('an empty query makes no request', () async {
    final result = await audius.searchTracks('   ');
    expect(items(result), isEmpty);
    expect(requests, isEmpty);
  });

  test('popular tracks come from the trending endpoint', () async {
    respond = (_) => _json({
      'data': [audiusTrackJson()],
    });
    final result = await audius.popularTracks();
    expect(requests.single.path, '/v1/tracks/trending');
    expect(items(result), hasLength(1));
  });

  test('a full page means more may follow; a short one ends paging', () async {
    respond = (_) => _json({
      'data': [for (var i = 0; i < 5; i++) audiusTrackJson(id: 'x$i')],
    });
    final full = await audius.popularTracks(
      page: const PageRequest(offset: 0, limit: 5),
    );
    expect((full as Ok<ProviderPage<Track>>).value.nextOffset, 5);

    final short = await audius.popularTracks(
      page: const PageRequest(offset: 5, limit: 10),
    );
    expect((short as Ok<ProviderPage<Track>>).value.hasMore, isFalse);
  });

  test('dropping dead tracks does not end paging early', () async {
    respond = (_) => _json({
      'data': [
        audiusTrackJson(id: 'a'),
        audiusTrackJson(id: 'b', deleted: true),
      ],
    });
    final page = await audius.popularTracks(page: const PageRequest(limit: 2));
    final value = (page as Ok<ProviderPage<Track>>).value;
    expect(value.items, hasLength(1));
    expect(value.nextOffset, 2);
  });

  test('page size is capped at what the API accepts', () async {
    await audius.popularTracks(page: const PageRequest(limit: 500));
    expect(requests.single.queryParameters['limit'], '100');
  });

  test('track details by ID', () async {
    respond = (_) => _json({'data': audiusTrackJson(id: 'D7KyD')});
    final result = await audius.trackDetails(const ExternalTrackId('D7KyD'));
    expect(requests.single.path, '/v1/tracks/D7KyD');
    expect((result as Ok<Track>).value.title, 'Ночной город');
  });

  test('a malformed ID is "not found" without a request', () async {
    final result = await audius.trackDetails(const ExternalTrackId('a/../b'));
    expect((result as Err).failure, isA<NotFoundFailure>());
    expect(requests, isEmpty);
  });

  test('HTTP failures reach the caller typed', () async {
    respond = (_) => _json({'error': 'slow down'}, 429);
    final result = await audius.searchTracks('x');
    expect((result as Err).failure, isA<RateLimitedFailure>());
  });

  test('a response without data is invalid, not an empty success', () async {
    respond = (_) => _json({'error': 'oops'});
    final result = await audius.popularTracks();
    expect((result as Err).failure, isA<InvalidResponseFailure>());

    respond = (_) => _json({'data': null});
    final details = await audius.trackDetails(const ExternalTrackId('abc'));
    expect((details as Err).failure, isA<InvalidResponseFailure>());
  });

  test(
    'the stream URL is the API endpoint, resolved without a request',
    () async {
      final result = await audius.streamUri(const ExternalTrackId('D7KyD'));
      final uri = (result as Ok<Uri>).value;
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.audius.co');
      expect(uri.path, '/v1/tracks/D7KyD/stream');
      expect(uri.queryParameters, {'app_name': 'MusicLab'});
      expect(requests, isEmpty);
    },
  );

  test('cancellation is passed to the request', () async {
    final cancellation = Cancellation()..cancel();
    final result = await audius.searchTracks('x', cancellation: cancellation);
    expect((result as Err).failure, isA<CancelledFailure>());
    expect(requests, isEmpty);
  });

  test('the player resolves an Audius track to its HTTPS stream', () async {
    final track = AudiusTrackMapper.fromJson(audiusTrackJson(id: 'D7KyD'))!;
    final resolver = TrackAudioResolver(providers: ProviderRegistry([audius]));
    final result = await resolver(track, Cancellation());
    final location = (result as Ok<AudioLocation>).value as StreamAudio;
    expect(location.uri.path, '/v1/tracks/D7KyD/stream');
    expect(requests, isEmpty);
  });

  group('bulk lookup', () {
    test('one request with repeated id parameters', () async {
      respond = (_) => _json({
        'data': [audiusTrackJson(id: 'b2'), audiusTrackJson(id: 'a1')],
      });
      final result = await audius.tracksByIds(const [
        ExternalTrackId('a1'),
        ExternalTrackId('b2'),
        ExternalTrackId('a1'),
        ExternalTrackId('bad/id'),
      ]);
      final uri = requests.single;
      expect(uri.path, '/v1/tracks');
      expect(uri.queryParametersAll['id'], ['a1', 'b2']);
      expect(uri.queryParameters['app_name'], 'MusicLab');
      expect((result as Ok<List<Track>>).value.map((t) => t.id.value).toSet(), {
        'audius:a1',
        'audius:b2',
      });
    });

    test('long lists are split into several requests', () async {
      respond = (_) => _json({'data': <Object>[]});
      await audius.tracksByIds([
        for (var i = 0; i < AudiusProvider.maxBatch + 3; i++)
          ExternalTrackId('t$i'),
      ]);
      expect(requests, hasLength(2));
      expect(requests.last.queryParametersAll['id'], hasLength(3));
    });

    test('a track that became unavailable is kept, marked', () async {
      respond = (_) => _json({
        'data': [audiusTrackJson(id: 'gone', deleted: true)],
      });
      final result = await audius.tracksByIds(const [ExternalTrackId('gone')]);
      final track = (result as Ok<List<Track>>).value.single;
      expect(
        (track.sources.single as ProviderTrackSource).availability,
        StreamAvailability.unavailable,
      );
    });

    test('a failure is passed on', () async {
      respond = (_) => _json({}, 503);
      final result = await audius.tracksByIds(const [ExternalTrackId('a')]);
      expect((result as Err).failure, isA<ServerFailure>());
    });
  });
}
