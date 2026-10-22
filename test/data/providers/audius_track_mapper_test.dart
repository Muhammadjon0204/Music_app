import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/providers/audius/audius_track_mapper.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track_source.dart';

import '../../helpers/audius_fixtures.dart';

ProviderTrackSource _source(Map<String, Object?> json) =>
    AudiusTrackMapper.fromJson(json)!.sources.single as ProviderTrackSource;

void main() {
  test('maps the metadata AURA uses', () {
    final track = AudiusTrackMapper.fromJson(audiusTrackJson())!;
    expect(track.id, const TrackId('audius:D7KyD'));
    expect(track.title, 'Ночной город');
    expect(track.artistName, 'Исполнитель');
    expect(track.duration, const Duration(seconds: 185));
    expect(track.year, 2025);
    expect(
      track.artworkUri,
      Uri.parse('https://node.example/content/abc/480x480.jpg'),
    );
    final source = track.sources.single as ProviderTrackSource;
    expect(source.providerId, const ProviderId('audius'));
    expect(source.externalId, const ExternalTrackId('D7KyD'));
    expect(source.availability, StreamAvailability.full);
    expect(
      source.originalUrl,
      Uri.parse('https://audius.co/artist/nochnoy-gorod-123'),
    );
    expect(source.license, 'All rights reserved');
  });

  test('the signed stream URL in the response is ignored', () {
    final track = AudiusTrackMapper.fromJson(audiusTrackJson())!;
    expect('${track.sources}', isNot(contains('SECRET')));
    expect('${track.artworkUri}', isNot(contains('SECRET')));
  });

  test('missing fields stay empty instead of being invented', () {
    final track = AudiusTrackMapper.fromJson(
      audiusTrackJson(
        userName: null,
        duration: null,
        artwork: null,
        permalink: null,
        license: null,
        releaseDate: null,
      ),
    )!;
    // Falls back to the handle, which the API always has.
    expect(track.artistName, 'artist');
    expect(track.duration, isNull);
    expect(track.artworkUri, isNull);
    expect(track.year, isNull);
    final source = track.sources.single as ProviderTrackSource;
    expect(source.originalUrl, isNull);
    expect(source.license, isNull);
  });

  test('unusable entries are dropped, not turned into fake tracks', () {
    expect(AudiusTrackMapper.fromJson(null), isNull);
    expect(AudiusTrackMapper.fromJson('track'), isNull);
    expect(AudiusTrackMapper.fromJson(audiusTrackJson(title: null)), isNull);
    expect(AudiusTrackMapper.fromJson(audiusTrackJson(title: '  ')), isNull);
    expect(AudiusTrackMapper.fromJson(audiusTrackJson(id: '../x')), isNull);
    expect(
      AudiusTrackMapper.fromJson({...audiusTrackJson(), 'duration': '3:05'}),
      isNotNull,
    );
  });

  group('availability', () {
    test('streamable for this app → full', () {
      expect(_source(audiusTrackJson()).availability, StreamAvailability.full);
    });

    test('gated (follow or purchase on Audius) → only on Audius', () {
      expect(
        _source(
          audiusTrackJson(
            accessStream: false,
            streamConditions: {'usdc_purchase': <String, Object?>{}},
          ),
        ).availability,
        StreamAvailability.externalOnly,
      );
    });

    test('deleted, unavailable or deactivated → unavailable', () {
      for (final json in [
        audiusTrackJson(deleted: true),
        audiusTrackJson(available: false),
        audiusTrackJson(deactivated: true),
        audiusTrackJson(streamable: false),
      ]) {
        expect(_source(json).availability, StreamAvailability.unavailable);
      }
    });

    test('no access and no stated reason → unknown, not playable', () {
      final source = _source(audiusTrackJson(accessStream: false));
      expect(source.availability, StreamAvailability.unknown);
      expect(source.availability.canStreamInApp, isFalse);
    });
  });

  test('only Audius pages become links; other hosts are refused', () {
    for (final permalink in [
      '//evil.example/x',
      'https://evil.example/x',
      'javascript:alert(1)',
    ]) {
      expect(
        _source(audiusTrackJson(permalink: permalink)).originalUrl,
        isNull,
      );
    }
  });

  test('non-HTTPS artwork is refused', () {
    final track = AudiusTrackMapper.fromJson(
      audiusTrackJson(artwork: {'480x480': 'http://node.example/a.jpg'}),
    )!;
    expect(track.artworkUri, isNull);
  });

  test('lists keep order and leave out unplayable-anywhere tracks', () {
    final tracks = AudiusTrackMapper.listFromJson([
      audiusTrackJson(id: 'a1'),
      audiusTrackJson(id: 'a2', deleted: true),
      'garbage',
      audiusTrackJson(
        id: 'a3',
        accessStream: false,
        streamConditions: {'follow_user_id': 1},
      ),
    ]);
    expect(tracks.map((t) => t.id.value), ['audius:a1', 'audius:a3']);
  });

  test('a non-list is an empty list', () {
    expect(AudiusTrackMapper.listFromJson({'data': 1}), isEmpty);
  });

  test('cover mirrors become alternatives on the same path', () {
    final track = AudiusTrackMapper.fromJson(
      audiusTrackJson(
        artwork: {
          '480x480': 'https://node.example/content/abc/480x480.jpg',
          'mirrors': [
            'https://mirror-1.example',
            'http://insecure.example',
            'https://node.example',
            42,
            'https://mirror-2.example',
          ],
        },
      ),
    )!;
    expect(track.artworkAlternatives, [
      Uri.parse('https://mirror-1.example/content/abc/480x480.jpg'),
      Uri.parse('https://mirror-2.example/content/abc/480x480.jpg'),
    ]);
  });
}
