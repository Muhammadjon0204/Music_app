import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/library/track_record.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

void main() {
  test('a record written before Phase 10 still reads', () {
    // Exactly what Phase 7 stored for a provider source: no availability,
    // no link, no license.
    final track = TrackRecord.fromMap('p:1', {
      'title': 'Old',
      'sources': [
        {'type': 'provider', 'provider': 'p', 'ref': '1'},
      ],
    });
    final source = track!.sources.single as ProviderTrackSource;
    expect(source.providerId, const ProviderId('p'));
    expect(source.externalId, const ExternalTrackId('1'));
    // Unknown is never treated as playable.
    expect(source.availability, StreamAvailability.unknown);
    expect(source.availability.canStreamInApp, isFalse);
    expect(source.originalUrl, isNull);
    expect(source.license, isNull);
  });

  test('a local track record is unchanged by the new fields', () {
    final local = Track(
      id: const TrackId('local-abc'),
      title: 'Мой трек',
      sources: const [LocalFileSource('library:audio/abc.mp3')],
    );
    final map = TrackRecord.toMap(local);
    expect(map['sources'], [
      {'type': 'local', 'ref': 'library:audio/abc.mp3'},
    ]);
    expect(TrackRecord.fromMap('local-abc', map), local);
  });

  test('an online track round-trips with availability, link and license', () {
    final source = ProviderTrackSource(
      providerId: const ProviderId('audius'),
      externalId: const ExternalTrackId('D7KyD'),
      availability: StreamAvailability.full,
      originalUrl: Uri.parse('https://audius.co/artist/song-123'),
      license: 'All rights reserved',
    );
    final track = Track(
      id: source.trackId,
      title: 'Song',
      artistName: 'Artist',
      artworkUri: Uri.parse('https://cdn.example/art/480x480.jpg'),
      sources: [source],
    );
    final read = TrackRecord.fromMap(
      source.trackId.value,
      TrackRecord.toMap(track),
    );
    expect(read, track);
  });

  test('no stream URL is ever written', () {
    final source = ProviderTrackSource(
      providerId: const ProviderId('audius'),
      externalId: const ExternalTrackId('x'),
      availability: StreamAvailability.full,
    );
    final map = TrackRecord.toMap(
      Track(id: source.trackId, title: 'T', sources: [source]),
    );
    expect('$map', isNot(contains('stream')));
  });

  test('unexpected stored values fall back safely', () {
    final track = TrackRecord.fromMap('p:1', {
      'title': 'T',
      'sources': [
        {
          'type': 'provider',
          'provider': 'p',
          'ref': '1',
          'availability': 'someFutureValue',
          'url': 'javascript:alert(1)',
          'license': 42,
        },
      ],
    });
    final source = track!.sources.single as ProviderTrackSource;
    expect(source.availability, StreamAvailability.unknown);
    // Only web links are kept.
    expect(source.originalUrl, isNull);
    expect(source.license, isNull);
  });

  group('identity', () {
    test('the same external ID at two providers gives two tracks', () {
      const a = ProviderTrackSource(
        providerId: ProviderId('audius'),
        externalId: ExternalTrackId('42'),
      );
      const b = ProviderTrackSource(
        providerId: ProviderId('jamendo'),
        externalId: ExternalTrackId('42'),
      );
      expect(a.trackId, isNot(b.trackId));
      expect(a.trackId, const TrackId('audius:42'));
    });

    test('provider IDs never collide with local IDs', () {
      const online = ProviderTrackSource(
        providerId: ProviderId('local'),
        externalId: ExternalTrackId('abc'),
      );
      expect(online.trackId.value, isNot('local-abc'));
    });

    test('identity does not depend on changing details', () {
      const before = ProviderTrackSource(
        providerId: ProviderId('audius'),
        externalId: ExternalTrackId('1'),
      );
      const after = ProviderTrackSource(
        providerId: ProviderId('audius'),
        externalId: ExternalTrackId('1'),
        availability: StreamAvailability.unavailable,
      );
      expect(before.trackId, after.trackId);
    });
  });
}
