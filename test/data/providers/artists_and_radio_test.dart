import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/data/providers/audius/audius_provider.dart';
import 'package:music_app/data/providers/audius/audius_track_mapper.dart';
import 'package:music_app/data/providers/jamendo/jamendo_provider.dart';
import 'package:music_app/data/providers/jamendo/jamendo_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';
import 'package:music_app/domain/providers/radio_mix.dart';

import '../../helpers/audius_fixtures.dart';
import '../../helpers/fake_providers.dart';
import 'jamendo_provider_test.dart' show jamendoTrackJson;

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

JsonHttpClient _client(List<Uri> requests, Object Function(Uri uri) answer) =>
    JsonHttpClient(
      client: MockClient((request) async {
        requests.add(request.url);
        return _json(answer(request.url));
      }),
      retryDelay: Duration.zero,
    );

ProviderTrackSource _source(Track track) =>
    track.sources.single as ProviderTrackSource;

void main() {
  group('track artists and genres', () {
    test('Audius: the user is the artist, the genre is kept', () {
      final track = AudiusTrackMapper.fromJson(audiusTrackJson())!;
      expect(_source(track).artistExternalId, const ExternalArtistId('u1'));
      expect(_source(track).genres, ['Electronic']);
    });

    test('Jamendo: artist_id and musicinfo genres', () {
      final json = jamendoTrackJson()
        ..['artist_id'] = '551562'
        ..['musicinfo'] = {
          'tags': {
            'genres': ['newage', ' ambient ', 7],
          },
        };
      final track = JamendoTrackMapper.fromJson(json)!;
      expect(_source(track).artistExternalId, const ExternalArtistId('551562'));
      expect(_source(track).genres, ['newage', 'ambient']);
    });
  });

  group('Audius artists', () {
    late List<Uri> requests;
    late Object Function(Uri uri) answer;
    late AudiusProvider audius;

    setUp(() {
      requests = [];
      answer = (_) => {'data': <Object>[]};
      audius = AudiusProvider(http: _client(requests, (u) => answer(u)));
    });

    test('the artist from /users/{id}', () async {
      answer = (_) => {
        'data': {
          'id': 'aWvp71',
          'name': 'Ciara Graves',
          'handle': 'ciaragraves',
          'bio': 'dj/producer',
          'follower_count': 657,
          'track_count': 6,
          'profile_picture': {'480x480': 'https://node.example/p/480x480.jpg'},
          'cover_photo': {'640x': 'https://node.example/c/640x.jpg'},
        },
      };
      final result = await audius.artist(const ExternalArtistId('aWvp71'));
      final artist = (result as Ok<OnlineArtist>).value;
      expect(requests.single.path, '/v1/users/aWvp71');
      expect(artist.name, 'Ciara Graves');
      expect(artist.followerCount, 657);
      expect(artist.imageUri!.path, '/p/480x480.jpg');
      expect(artist.coverUri!.path, '/c/640x.jpg');
      expect(artist.pageUrl, Uri.parse('https://audius.co/ciaragraves'));
    });

    test('the artist tracks, most played first', () async {
      answer = (_) => {
        'data': [audiusTrackJson(id: 'a'), audiusTrackJson(id: 'b')],
      };
      final result = await audius.artistTracks(
        const ExternalArtistId('aWvp71'),
      );
      expect(requests.single.path, '/v1/users/aWvp71/tracks');
      expect(requests.single.queryParameters['sort'], 'plays');
      expect((result as Ok<ProviderPage<Track>>).value.items, hasLength(2));
    });

    test('radio: the genre trending, mixed with the artist', () async {
      answer = (uri) => uri.path.contains('/users/')
          ? {
              'data': [
                audiusTrackJson(id: 'own1'),
                audiusTrackJson(id: 'D7KyD'),
              ],
            }
          : {
              'data': [audiusTrackJson(id: 'g1'), audiusTrackJson(id: 'g2')],
            };
      final seed = AudiusTrackMapper.fromJson(audiusTrackJson())!;
      final result = await audius.radioFor(seed);

      final trending = requests.firstWhere((u) => u.path.endsWith('trending'));
      expect(trending.queryParameters['genre'], 'Electronic');
      expect(requests.any((u) => u.path == '/v1/users/u1/tracks'), isTrue);
      expect((result as Ok<List<Track>>).value.map((t) => t.id.value), [
        'audius:g1',
        'audius:own1',
        'audius:g2',
      ]);
    });

    test('an invalid artist ID makes no request', () async {
      await audius.artist(const ExternalArtistId('../x'));
      expect(requests, isEmpty);
    });
  });

  group('Jamendo artists', () {
    late List<Uri> requests;
    late Object Function(Uri uri) answer;
    late JamendoProvider jamendo;

    Map<String, Object?> results(List<Object?> items) => {
      'headers': {'status': 'success', 'code': 0},
      'results': items,
    };

    setUp(() {
      requests = [];
      answer = (_) => results(const []);
      jamendo = JamendoProvider(
        clientId: 'test-client',
        http: _client(requests, (u) => answer(u)),
      );
    });

    test('the artist from /artists/', () async {
      answer = (_) => results([
        {
          'id': '551562',
          'name': 'StimiBeats',
          'image': 'https://usercontent.jamendo.com?type=artist&id=551562',
          'shareurl': 'https://www.jamendo.com/artist/551562',
        },
      ]);
      final result = await jamendo.artist(const ExternalArtistId('551562'));
      final artist = (result as Ok<OnlineArtist>).value;
      expect(requests.single.path, '/v3.0/artists/');
      expect(requests.single.queryParameters.containsKey('include'), isFalse);
      expect(artist.name, 'StimiBeats');
      expect(artist.pageUrl!.host, 'www.jamendo.com');
    });

    test('artist tracks and radio by genre tags', () async {
      answer = (uri) => results([
        jamendoTrackJson(id: uri.queryParameters['artist_id'] ?? '9'),
      ]);
      await jamendo.artistTracks(const ExternalArtistId('551562'));
      expect(requests.single.queryParameters['artist_id'], '551562');
      expect(requests.single.queryParameters['order'], 'popularity_total');

      requests.clear();
      final json = jamendoTrackJson(id: '1')
        ..['artist_id'] = '551562'
        ..['musicinfo'] = {
          'tags': {
            'genres': ['newage', 'ambient'],
          },
        };
      final seed = JamendoTrackMapper.fromJson(json)!;
      await jamendo.radioFor(seed);
      final tagged = requests.firstWhere(
        (u) => u.queryParameters.containsKey('fuzzytags'),
      );
      expect(tagged.queryParameters['fuzzytags'], 'newage ambient');
    });
  });

  group('radio mix', () {
    test('one from each list in turn, each once, without the seed', () {
      final seed = onlineTrack('seed');
      final mixed = mixForRadio(
        [
          [onlineTrack('a'), onlineTrack('seed'), onlineTrack('b')],
          [onlineTrack('x'), onlineTrack('a')],
        ],
        seed: seed,
        limit: 10,
      );
      expect(mixed.map((t) => t.title), ['Online a', 'Online x', 'Online b']);
    });

    test('tracks that cannot play here are left out; the limit holds', () {
      final mixed = mixForRadio(
        [
          [
            onlineTrack('gone', availability: StreamAvailability.unavailable),
            onlineTrack('1'),
            onlineTrack('2'),
            onlineTrack('3'),
          ],
        ],
        seed: onlineTrack('seed'),
        limit: 2,
        exclude: {const TrackId('catalog:2')},
      );
      expect(mixed.map((t) => t.title), ['Online 1', 'Online 3']);
    });
  });
}
