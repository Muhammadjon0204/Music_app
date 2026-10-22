import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/library/library_keys.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';

/// Home content built from the user's library. While the library is empty
/// it shows [whenEmpty] (labelled demo content) if given, else nothing.
final class LibraryHomeFeedSource implements HomeFeedSource {
  const LibraryHomeFeedSource({required this._repository, this._whenEmpty});

  static const _carouselLimit = 10;

  final LibraryRepository _repository;
  final HomeFeedSource? _whenEmpty;

  @override
  Future<Result<HomeFeed>> load() async {
    final library = _repository.current;
    if (library.isEmpty) {
      return _whenEmpty?.load() ??
          Ok(
            HomeFeed(
              recentlyAdded: const [],
              albums: const [],
              playlists: const [],
            ),
          );
    }
    return Ok(buildFeed(library));
  }

  static HomeFeed buildFeed(LibrarySnapshot library) {
    final favorites = library.favorites;
    final hasFavorites = favorites.isNotEmpty;
    final featuredTracks = hasFavorites
        ? favorites
        : sortTracks(library.tracks, TrackSort.title);

    // Albums ordered by their most recently added track (one pass).
    final latestByAlbum = <AlbumId, DateTime>{};
    for (final track in library.tracks) {
      final key = albumKeyOf(track);
      if (key == null) continue;
      final added = track.addedAt ?? DateTime(0);
      final known = latestByAlbum[key];
      if (known == null || added.isAfter(known)) latestByAlbum[key] = added;
    }
    final recentAlbums = [...library.albums]
      ..sort(
        (a, b) => (latestByAlbum[b.id] ?? DateTime(0)).compareTo(
          latestByAlbum[a.id] ?? DateTime(0),
        ),
      );

    return HomeFeed(
      featured: Playlist(
        id: const PlaylistId('home-featured'),
        name: '',
        trackIds: [for (final t in featuredTracks) t.id],
      ),
      featuredKind: hasFavorites
          ? HomeFeaturedKind.favorites
          : HomeFeaturedKind.allTracks,
      featuredTracks: featuredTracks,
      recentlyAdded: recentAlbums.take(_carouselLimit).toList(),
      albums: library.albums.take(_carouselLimit).toList(),
      playlists: library.playlists.take(_carouselLimit).toList(),
    );
  }
}
