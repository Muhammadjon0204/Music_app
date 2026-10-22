import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/config/app_config.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/artist.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/home/greeting.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

const local = LocalFileSource('a.mp3');
const remote = ProviderTrackSource(
  providerId: ProviderId('p'),
  externalId: ExternalTrackId('1'),
);

Track track(List<TrackSource> sources) =>
    Track(id: const TrackId('t'), title: 'T', sources: sources);

void main() {
  group('Track', () {
    test('a track can have local and online sources at once', () {
      expect(track([local, remote]).sources, [local, remote]);
    });

    test('source order is significant (preferred source first)', () {
      expect(track([local, remote]), isNot(track([remote, local])));
    });

    test('equal tracks have equal hash codes', () {
      expect(track([local, remote]).hashCode, track([local, remote]).hashCode);
    });

    test('a local and an online source are never equal', () {
      expect(local, isNot(remote));
    });
  });

  group('Album, Artist, Playlist', () {
    test('value equality and hash codes', () {
      Album album() => const Album(id: AlbumId('a'), title: 'A', year: 2024);
      Artist artist() => const Artist(id: ArtistId('x'), name: 'X');
      Playlist playlist() => Playlist(
        id: const PlaylistId('p'),
        name: 'P',
        trackIds: const [TrackId('1'), TrackId('2')],
      );

      expect(album(), album());
      expect(album().hashCode, album().hashCode);
      expect(artist(), artist());
      expect(playlist(), playlist());
      expect(playlist().hashCode, playlist().hashCode);
    });

    test('playlist track list cannot be changed from outside', () {
      final ids = [const TrackId('1')];
      final playlist = Playlist(
        id: const PlaylistId('p'),
        name: 'P',
        trackIds: ids,
      );
      ids.add(const TrackId('2'));

      expect(playlist.trackIds, hasLength(1));
      expect(
        () => playlist.trackIds.add(const TrackId('3')),
        throwsUnsupportedError,
      );
    });
  });

  group('HomeFeed', () {
    test('isEmpty only when every part is empty', () {
      HomeFeed feed({Playlist? featured, List<Album> albums = const []}) =>
          HomeFeed(
            featured: featured,
            recentlyAdded: const [],
            albums: albums,
            playlists: const [],
          );

      expect(feed().isEmpty, isTrue);
      expect(
        feed(
          featured: Playlist(
            id: const PlaylistId('f'),
            name: 'F',
            trackIds: const [],
          ),
        ).isEmpty,
        isFalse,
      );
      expect(
        feed(
          albums: const [Album(id: AlbumId('a'), title: 'A')],
        ).isEmpty,
        isFalse,
      );
    });

    test('equality includes the demo flag', () {
      HomeFeed feed({required bool demo}) => HomeFeed(
        recentlyAdded: const [],
        albums: const [],
        playlists: const [],
        isDemo: demo,
      );
      expect(feed(demo: true), feed(demo: true));
      expect(feed(demo: true), isNot(feed(demo: false)));
    });
  });

  group('PlaybackSnapshot', () {
    test('a new failure is a new state, so the UI is notified', () {
      const failure = NetworkFailure();
      PlaybackSnapshot withFailure(AppFailure? f) =>
          PlaybackSnapshot(queue: const [], failure: f);

      expect(withFailure(failure), withFailure(failure));
      // A separate occurrence of the same failure (not a canonical const).
      final again = NetworkFailure();
      expect(withFailure(failure), isNot(withFailure(again)));
      expect(withFailure(failure), isNot(withFailure(null)));
    });

    test('negative index is rejected', () {
      expect(
        () => PlaybackSnapshot(
          queue: [
            track([local]),
          ],
          currentIndex: -1,
        ),
        throwsRangeError,
      );
    });

    test('queue cannot be changed from outside', () {
      final snapshot = PlaybackSnapshot(
        queue: [
          track([local]),
        ],
      );
      expect(() => snapshot.queue.clear(), throwsUnsupportedError);
    });
  });

  group('core', () {
    test('elementsEqual edge cases', () {
      final list = [1, 2];
      expect(elementsEqual(list, list), isTrue);
      expect(elementsEqual(<int>[], <int>[]), isTrue);
      expect(elementsEqual([1], [1, 2]), isFalse);
      expect(elementsEqual<int?>([null], [null]), isTrue);
      expect(elementsEqual<int?>([null], [1]), isFalse);
    });

    test('Result works with exhaustive pattern matching', () {
      String describe(Result<int> r) => switch (r) {
        Ok(:final value) => 'ok $value',
        Err(:final failure) => 'err ${failure.runtimeType}',
      };
      expect(describe(const Ok(1)), 'ok 1');
      expect(describe(const Err(StorageFailure())), 'err StorageFailure');
    });

    test('AppConfig rejects near-miss environment names', () {
      for (final raw in ['Production', ' production', 'prod', 'DEV']) {
        expect(
          () => AppConfig.parse(raw, isReleaseBuild: true),
          throwsArgumentError,
          reason: raw,
        );
      }
    });
  });

  group('formatting', () {
    test('duration boundaries', () {
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(formatDuration(const Duration(hours: 100)), '100:00:00');
      expect(
        formatDuration(const Duration(minutes: 59, milliseconds: 59999)),
        '59:59',
      );
    });

    test('plural forms for negative and large numbers', () {
      expect(pluralRu(-1, 'трек', 'трека', 'треков'), 'трек');
      expect(pluralRu(-12, 'трек', 'трека', 'треков'), 'треков');
      expect(pluralRu(1000001, 'трек', 'трека', 'треков'), 'трек');
      expect(pluralRu(1011, 'трек', 'трека', 'треков'), 'треков');
    });

    test('every hour has a greeting; it changes only at 5, 12, 17, 23', () {
      final changes = <int>[];
      for (var hour = 1; hour < 24; hour++) {
        final previous = greetingFor(DateTime(2026, 1, 1, hour - 1));
        if (greetingFor(DateTime(2026, 1, 1, hour)) != previous) {
          changes.add(hour);
        }
      }
      expect(changes, [5, 12, 17, 23]);
    });
  });
}
