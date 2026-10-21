import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

Track _track({
  String title = 'Song',
  List<TrackSource> sources = const [LocalFileSource('a.mp3')],
  String? artistName,
}) => Track(
  id: const TrackId('t1'),
  title: title,
  sources: sources,
  artistName: artistName,
);

void main() {
  group('Track', () {
    test('equal when all fields match, including sources', () {
      expect(_track(), _track());
      expect(_track().hashCode, _track().hashCode);
    });

    test('differs when metadata changes', () {
      expect(_track(artistName: 'A'), isNot(_track(artistName: 'B')));
    });

    test('differs when sources change', () {
      expect(
        _track(),
        isNot(_track(sources: const [LocalFileSource('b.mp3')])),
      );
    });

    test('missing artist is null, not a placeholder string', () {
      expect(_track().artistName, isNull);
    });

    test('rejects an empty title', () {
      expect(() => _track(title: '  '), throwsArgumentError);
    });

    test('rejects a track without sources', () {
      expect(() => _track(sources: const []), throwsArgumentError);
    });

    test('sources cannot be mutated from outside', () {
      final input = <TrackSource>[const LocalFileSource('a.mp3')];
      final track = _track(sources: input);

      input.add(const LocalFileSource('b.mp3'));

      expect(track.sources, hasLength(1));
      expect(
        () => track.sources.add(const LocalFileSource('c.mp3')),
        throwsUnsupportedError,
      );
    });
  });

  group('TrackSource', () {
    test('provider source is identified by provider and external id', () {
      const a = ProviderTrackSource(
        providerId: ProviderId('p'),
        externalId: ExternalTrackId('42'),
      );
      const sameIdOtherProvider = ProviderTrackSource(
        providerId: ProviderId('q'),
        externalId: ExternalTrackId('42'),
      );

      expect(
        a,
        const ProviderTrackSource(
          providerId: ProviderId('p'),
          externalId: ExternalTrackId('42'),
        ),
      );
      expect(a, isNot(sameIdOtherProvider));
    });
  });
}
