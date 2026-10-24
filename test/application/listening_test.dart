import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/cancellation.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/in_memory_listening_store.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';
import '../helpers/fakes.dart';

/// A provider that answers bulk lookups from a fixed catalog.
class _BatchProvider implements BatchTrackDetailsProvider {
  _BatchProvider(this.catalog);

  final Map<String, Track> catalog;
  final requests = <List<String>>[];
  AppFailure? failWith;

  @override
  ProviderId get id => const ProviderId('catalog');

  @override
  String get displayName => 'Каталог';

  @override
  Future<Result<List<Track>>> tracksByIds(
    List<ExternalTrackId> ids, {
    Cancellation? cancellation,
  }) async {
    requests.add([for (final i in ids) i.value]);
    final failure = failWith;
    if (failure != null) return Err(failure);
    return Ok([for (final i in ids) ?catalog[i.value]]);
  }
}

Track _local(String name, {Duration duration = const Duration(minutes: 3)}) =>
    Track(
      id: TrackId('local-$name'),
      title: name,
      duration: duration,
      sources: [LocalFileSource('/m/$name.mp3')],
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('online lookup', () {
    late _BatchProvider provider;
    late ProviderContainer container;

    setUp(() {
      provider = _BatchProvider({'1': onlineTrack('1'), '2': onlineTrack('2')});
      container = ProviderContainer.test(
        overrides: [
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry([provider]),
          ),
        ],
      );
    });

    OnlineTrackCache cache() =>
        container.read(onlineTrackCacheProvider.notifier);

    test('looks up unknown tracks in one request', () async {
      await cache().fetch(const [
        TrackId('catalog:1'),
        TrackId('catalog:2'),
        TrackId('local-x'),
      ]);
      expect(provider.requests, [
        ['1', '2'],
      ]);
      expect(container.read(onlineTrackCacheProvider).tracks, hasLength(2));
    });

    test('known and missing IDs are not requested again', () async {
      await cache().fetch(const [
        TrackId('catalog:1'),
        TrackId('catalog:gone'),
      ]);
      await cache().fetch(const [
        TrackId('catalog:1'),
        TrackId('catalog:gone'),
      ]);
      expect(provider.requests, hasLength(1));
      expect(container.read(onlineTrackCacheProvider).missing, {
        const TrackId('catalog:gone'),
      });
    });

    test('a failed lookup is reported and retried later', () async {
      provider.failWith = const NetworkFailure();
      final result = await cache().fetch(const [TrackId('catalog:1')]);
      expect((result as Err).failure, isA<NetworkFailure>());
      expect(container.read(onlineTrackCacheProvider).missing, isEmpty);

      provider.failWith = null;
      await cache().fetch(const [TrackId('catalog:1')]);
      expect(provider.requests, hasLength(2));
    });

    test('tracks seen in search or popular lists need no lookup', () async {
      cache().remember([onlineTrack('1')]);
      await cache().fetch(const [TrackId('catalog:1')]);
      expect(provider.requests, isEmpty);
    });

    test('online favorites resolve in favorite order', () async {
      final library = InMemoryLibraryRepository();
      final container = ProviderContainer.test(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(library),
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry([provider]),
          ),
        ],
      );
      container.listen(onlineFavoritesProvider, (_, _) {});
      await library.setFavorite(const TrackId('catalog:2'), favorite: true);
      await library.setFavorite(const TrackId('catalog:gone'), favorite: true);
      await library.setFavorite(const TrackId('catalog:1'), favorite: true);
      await _settle();

      final resolved = await container.read(onlineFavoritesProvider.future);
      expect(resolved.tracks.map((t) => t.title), ['Online 1', 'Online 2']);
      expect(resolved.unavailable, 1);
    });
  });

  group('recorder', () {
    late FakePlaybackController player;
    late InMemoryListeningStore store;
    late ListeningRecorder recorder;
    final a = _local('a');
    final b = _local('b');

    setUp(() {
      player = FakePlaybackController(PlaybackSnapshot.initial);
      store = InMemoryListeningStore();
      recorder = ListeningRecorder(
        player: player,
        store: store,
        now: () => DateTime(2026, 1, 1),
      )..start();
    });

    tearDown(() => recorder.dispose());

    Future<List<String>> history() async => [
      for (final e in await store.watchHistory().first) e.trackId.value,
    ];

    void playing(
      Track track, {
      PlaybackStatus status = PlaybackStatus.playing,
    }) => player.emit(
      PlaybackSnapshot(
        queue: [a, b],
        currentIndex: track == a ? 0 : 1,
        status: status,
      ),
    );

    test('a listen counts after 30 seconds of real playback', () async {
      playing(a);
      player.emitPosition(const Duration(seconds: 29));
      await _settle();
      expect(await history(), isEmpty);

      player.emitPosition(const Duration(seconds: 30));
      player.emitPosition(const Duration(seconds: 45));
      await _settle();
      expect(await history(), ['local-a']);
    });

    test('paused or buffering time does not count', () async {
      playing(a, status: PlaybackStatus.buffering);
      player.emitPosition(const Duration(seconds: 40));
      await _settle();
      expect(await history(), isEmpty);
    });

    test('short tracks count after half their length', () async {
      final short = _local('s', duration: const Duration(seconds: 20));
      player.emit(
        PlaybackSnapshot(
          queue: [short],
          currentIndex: 0,
          status: PlaybackStatus.playing,
        ),
      );
      player.emitPosition(const Duration(seconds: 10));
      await _settle();
      expect(await history(), ['local-s']);
    });

    test('each play counts once; playing it again counts again', () async {
      playing(a);
      player.emitPosition(const Duration(seconds: 31));
      playing(b);
      player.emitPosition(const Duration(seconds: 31));
      playing(a);
      player.emitPosition(const Duration(seconds: 31));
      await _settle();
      expect(await history(), ['local-a', 'local-b', 'local-a']);
    });

    test('the session is saved when the queue changes, not at start', () async {
      expect(await store.loadSession(), isNull);
      playing(b);
      await _settle();
      final session = (await store.loadSession())!;
      expect(session.queue, [a.id, b.id]);
      expect(session.index, 1);
    });

    test('the position is saved on pause and every few seconds', () async {
      playing(a);
      player.emitPosition(const Duration(seconds: 12));
      await _settle();
      expect(
        (await store.loadSession())!.position,
        const Duration(seconds: 12),
      );

      player.emitPosition(const Duration(seconds: 15));
      playing(a, status: PlaybackStatus.paused);
      await _settle();
      expect(
        (await store.loadSession())!.position,
        const Duration(seconds: 15),
      );
    });
  });

  group('restore', () {
    late FakePlaybackController player;
    late InMemoryListeningStore store;
    late InMemoryLibraryRepository library;
    late _BatchProvider provider;

    setUp(() async {
      player = FakePlaybackController(PlaybackSnapshot.initial);
      store = InMemoryListeningStore();
      library = InMemoryLibraryRepository();
      await library.addTracks([_local('a'), _local('b')]);
      provider = _BatchProvider({'1': onlineTrack('1')});
    });

    Future<void> restore() async {
      final container = ProviderContainer.test(
        overrides: [
          libraryRepositoryProvider.overrideWithValue(library),
          listeningStoreProvider.overrideWithValue(store),
          playbackControllerProvider.overrideWithValue(player),
          providerRegistryProvider.overrideWithValue(
            ProviderRegistry([provider]),
          ),
        ],
      );
      container.listen(listeningSessionProvider, (_, _) {});
      await container.read(listeningSessionProvider.future);
    }

    test('the queue comes back paused, where it stopped', () async {
      await store.saveSession(
        SavedSession(
          queue: const [TrackId('local-a'), TrackId('catalog:1')],
          index: 1,
          position: const Duration(seconds: 80),
          repeatMode: PlaybackRepeatMode.all,
        ),
      );
      await restore();

      expect(player.lastQueue!.map((t) => t.title), ['a', 'Online 1']);
      expect(player.lastStartIndex, 1);
      expect(player.seeks, [const Duration(seconds: 80)]);
      expect(player.repeatMode, PlaybackRepeatMode.all);
      // Restored paused: nothing starts by itself.
      expect(player.playCalls, 0);
    });

    test('tracks that no longer exist are left out', () async {
      await store.saveSession(
        SavedSession(
          queue: const [
            TrackId('local-gone'),
            TrackId('local-b'),
            TrackId('catalog:removed'),
          ],
          index: 1,
          position: const Duration(seconds: 10),
        ),
      );
      await restore();
      expect(player.lastQueue!.map((t) => t.title), ['b']);
      expect(player.lastStartIndex, 0);
      expect(player.seeks, [const Duration(seconds: 10)]);
    });

    test(
      'a vanished current track starts the rest from the beginning',
      () async {
        await store.saveSession(
          SavedSession(
            queue: const [TrackId('local-a'), TrackId('local-gone')],
            index: 1,
            position: const Duration(seconds: 50),
          ),
        );
        await restore();
        expect(player.lastQueue!.map((t) => t.title), ['a']);
        expect(player.seeks, isEmpty);
      },
    );

    test('offline: local tracks come back, the session is kept', () async {
      provider.failWith = const NetworkFailure();
      final saved = SavedSession(queue: const [TrackId('catalog:1')], index: 0);
      await store.saveSession(saved);
      await restore();
      expect(player.lastQueue, isNull);
      // Not overwritten: it can be restored next time.
      expect((await store.loadSession())!.queue, saved.queue);
    });

    test('nothing is restored over music that already plays', () async {
      player = FakePlaybackController(
        PlaybackSnapshot(queue: [_local('x')], currentIndex: 0),
      );
      await store.saveSession(
        SavedSession(queue: const [TrackId('local-a')], index: 0),
      );
      await restore();
      expect(player.lastQueue, isNull);
    });
  });
}
