import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/data/library/in_memory_listening_store.dart';
import 'package:music_app/data/library/sembast_library_repository.dart';
import 'package:music_app/data/library/sembast_listening_store.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:sembast/sembast_memory.dart';

HistoryEntry _entry(String id, int minute) => HistoryEntry(
  trackId: TrackId(id),
  playedAt: DateTime(2026, 1, 1, 12, minute),
);

void main() {
  final implementations = <String, Future<ListeningStore> Function()>{
    'in memory': () async => InMemoryListeningStore(),
    'sembast': () async {
      final db = await newDatabaseFactoryMemory().openDatabase('t.db');
      return SembastListeningStore(db);
    },
  };

  for (final MapEntry(key: name, value: create) in implementations.entries) {
    group(name, () {
      late ListeningStore store;
      setUp(() async => store = await create());

      test('history is newest first', () async {
        await store.addToHistory(_entry('a', 1));
        await store.addToHistory(_entry('b', 2));
        await store.addToHistory(_entry('a', 3));
        final history = await store.watchHistory().first;
        expect(history.map((e) => e.trackId.value), ['a', 'b', 'a']);
      });

      test('history is capped', () async {
        for (var i = 0; i < historyLimit + 5; i++) {
          await store.addToHistory(_entry('t$i', i % 60));
        }
        final history = await store.watchHistory().first;
        expect(history, hasLength(historyLimit));
        expect(history.first.trackId.value, 't${historyLimit + 4}');
      });

      test('history can be cleared', () async {
        await store.addToHistory(_entry('a', 1));
        await store.clearHistory();
        expect(await store.watchHistory().first, isEmpty);
      });

      test('the session round-trips', () async {
        expect(await store.loadSession(), isNull);
        await store.saveSession(
          SavedSession(
            queue: const [TrackId('local-1'), TrackId('audius:D7KyD')],
            index: 1,
            position: const Duration(seconds: 95),
            repeatMode: PlaybackRepeatMode.all,
          ),
        );
        final session = (await store.loadSession())!;
        expect(session.queue, const [
          TrackId('local-1'),
          TrackId('audius:D7KyD'),
        ]);
        expect(session.index, 1);
        expect(session.position, const Duration(seconds: 95));
        expect(session.repeatMode, PlaybackRepeatMode.all);

        await store.saveSession(null);
        expect(await store.loadSession(), isNull);
      });
    });
  }

  group('sembast file', () {
    test('a broken stored session is ignored, not a crash', () async {
      final db = await newDatabaseFactoryMemory().openDatabase('t.db');
      await stringMapStoreFactory.store('session').record('last').put(db, {
        'queue': ['a'],
        'index': 7,
      });
      expect(await SembastListeningStore(db).loadSession(), isNull);
    });

    test(
      'a Phase 7 library database gains history without migration',
      () async {
        final factory = newDatabaseFactoryMemory();
        final library = await SembastLibraryRepository.open(
          factory: factory,
          path: 'library.db',
        );
        await library.addTracks([
          Track(
            id: const TrackId('local-1'),
            title: 'Мой трек',
            sources: const [LocalFileSource('/m/1.mp3')],
          ),
        ]);
        await library.setFavorite(
          const TrackId('audius:D7KyD'),
          favorite: true,
        );

        final store = SembastListeningStore(library.database);
        await store.addToHistory(_entry('local-1', 1));
        await library.close();

        final reopened = await SembastLibraryRepository.open(
          factory: factory,
          path: 'library.db',
        );
        expect(reopened.current.tracks.single.title, 'Мой трек');
        expect(reopened.current.onlineFavoriteIds, const [
          TrackId('audius:D7KyD'),
        ]);
        final history = await SembastListeningStore(reopened.database)
            .watchHistory()
            .first;
        expect(history.single.trackId, const TrackId('local-1'));
      },
    );
  });

  group('references', () {
    test('online IDs split into provider and external ID', () {
      expect(providerRefOf(const TrackId('audius:D7KyD')), (
        const ProviderId('audius'),
        const ExternalTrackId('D7KyD'),
      ));
    });

    test('local and demo IDs are not references', () {
      for (final id in ['local-abc', 'demo-tone-1', ':x', 'x:']) {
        expect(providerRefOf(TrackId(id)), isNull);
      }
    });
  });
}
