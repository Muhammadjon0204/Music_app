import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/in_memory_library_repository.dart';
import 'package:music_app/data/library/sembast_library_repository.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:sembast/sembast_memory.dart';

Track track(String id, {String? artist, String? album, int? number}) => Track(
  id: TrackId(id),
  title: 'Title $id',
  artistName: artist,
  albumTitle: album,
  trackNumber: number,
  sources: [LocalFileSource('library:audio/$id.mp3')],
);

/// Every LibraryRepository must pass these, whatever its storage.
void main() {
  final implementations = <String, Future<LibraryRepository> Function()>{
    'in memory': () async => InMemoryLibraryRepository(),
    'sembast': () => SembastLibraryRepository.open(
      factory: newDatabaseFactoryMemory(),
      path: 'test.db',
    ),
  };

  for (final MapEntry(key: name, value: create) in implementations.entries) {
    group(name, () {
      late LibraryRepository repo;
      setUp(() async => repo = await create());

      Playlist createdPlaylist(Result<Playlist> result) =>
          (result as Ok<Playlist>).value;

      test('starts empty', () {
        expect(repo.current.isEmpty, isTrue);
      });

      test('adds and replaces tracks by id', () async {
        await repo.addTracks([track('a'), track('b')]);
        await repo.addTracks([track('a', artist: 'New')]);
        expect(repo.current.tracks, hasLength(2));
        expect(repo.current.track(const TrackId('a'))!.artistName, 'New');
      });

      test('watch emits the current snapshot, then each change', () async {
        final seen = <LibrarySnapshot>[];
        final sub = repo.watch().listen(seen.add);
        await Future<void>.delayed(Duration.zero);
        await repo.addTracks([track('a')]);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(seen.first.isEmpty, isTrue);
        expect(seen.last.tracks, hasLength(1));
      });

      test(
        'favorites: newest first, toggles, ignores removed tracks',
        () async {
          await repo.addTracks([track('a'), track('b')]);
          await repo.setFavorite(const TrackId('a'), favorite: true);
          await repo.setFavorite(const TrackId('b'), favorite: true);
          expect(repo.current.favorites.map((t) => t.id.value), ['b', 'a']);

          await repo.setFavorite(const TrackId('b'), favorite: false);
          expect(repo.current.isFavorite(const TrackId('b')), isFalse);

          await repo.removeTracks({const TrackId('a')});
          expect(repo.current.favorites, isEmpty);
        },
      );

      test(
        'playlists: create, add, duplicates allowed, remove entry',
        () async {
          await repo.addTracks([track('a'), track('b')]);
          final p = createdPlaylist(await repo.createPlaylist('  Мой  '));
          expect(p.name, 'Мой');

          await repo.addToPlaylist(p.id, [
            const TrackId('a'),
            const TrackId('b'),
            const TrackId('a'),
          ]);
          expect(repo.current.playlist(p.id)!.trackIds, hasLength(3));

          await repo.removeFromPlaylist(p.id, 2);
          expect(repo.current.playlist(p.id)!.trackIds.map((t) => t.value), [
            'a',
            'b',
          ]);
        },
      );

      test('removing a track drops it from every playlist', () async {
        await repo.addTracks([track('a'), track('b')]);
        final p = createdPlaylist(await repo.createPlaylist('P'));
        await repo.addToPlaylist(p.id, [
          const TrackId('a'),
          const TrackId('b'),
        ]);

        await repo.removeTracks({const TrackId('a')});

        expect(repo.current.playlist(p.id)!.trackIds.map((t) => t.value), [
          'b',
        ]);
      });

      test('rename and delete playlists', () async {
        final p = createdPlaylist(await repo.createPlaylist('Old'));
        await repo.renamePlaylist(p.id, 'New');
        expect(repo.current.playlist(p.id)!.name, 'New');
        await repo.deletePlaylist(p.id);
        expect(repo.current.playlists, isEmpty);
      });

      test('invalid names and indexes are rejected without changes', () async {
        expect(await repo.createPlaylist('   '), isA<Err<Playlist>>());
        expect(await repo.createPlaylist('x' * 101), isA<Err<Playlist>>());
        final p = createdPlaylist(await repo.createPlaylist('P'));
        expect(await repo.renamePlaylist(p.id, ''), isA<Err<void>>());
        expect(await repo.removeFromPlaylist(p.id, 0), isA<Err<void>>());
        final missing = await repo.addToPlaylist(const PlaylistId('nope'), [
          const TrackId('a'),
        ]);
        expect((missing as Err).failure, isA<AppFailure>());
        expect(repo.current.playlist(p.id)!.name, 'P');
      });

      test('playlists keep their creation order', () async {
        for (final name in ['first', 'second', 'third']) {
          await repo.createPlaylist(name);
        }
        expect(repo.current.playlists.map((p) => p.name), [
          'first',
          'second',
          'third',
        ]);
      });
    });
  }

  group('sembast persistence', () {
    test('the library survives closing and reopening', () async {
      final factory = newDatabaseFactoryMemory();
      final first = await SembastLibraryRepository.open(
        factory: factory,
        path: 'lib.db',
      );
      await first.addTracks([track('a', artist: 'Кино', album: 'Звезда')]);
      await first.setFavorite(const TrackId('a'), favorite: true);
      final p = (await first.createPlaylist('Вечер') as Ok<Playlist>).value;
      await first.addToPlaylist(p.id, [const TrackId('a')]);
      await first.close();

      final reopened = await SembastLibraryRepository.open(
        factory: factory,
        path: 'lib.db',
      );
      final library = reopened.current;
      expect(library.tracks.single.artistName, 'Кино');
      expect(library.favorites.single.id, const TrackId('a'));
      expect(library.playlists.single.name, 'Вечер');
      expect(library.tracksOf(library.playlists.single), hasLength(1));
      await reopened.close();
    });

    test('unreadable records are skipped, not fatal', () async {
      final factory = newDatabaseFactoryMemory();
      final db = await factory.openDatabase('bad.db');
      final tracks = stringMapStoreFactory.store('tracks');
      await tracks.record('broken').put(db, {'title': 42});
      await tracks.record('no-source').put(db, {'title': 'x', 'sources': []});
      await tracks.record('ok').put(db, {
        'title': 'Fine',
        'sources': [
          {'type': 'local', 'ref': 'library:audio/ok.mp3'},
        ],
      });
      await db.close();

      final repo = await SembastLibraryRepository.open(
        factory: factory,
        path: 'bad.db',
      );
      expect(repo.current.tracks.single.title, 'Fine');
      expect(repo.skippedRecords, 2);
      await repo.close();
    });
  });
}
