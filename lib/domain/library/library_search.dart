import 'package:music_app/domain/library/library_keys.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/artist.dart';
import 'package:music_app/domain/music/track.dart';

final class LibrarySearchResult {
  const LibrarySearchResult({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
  });

  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;

  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty;
}

/// Finds library items whose names contain every word of [query], ignoring
/// case and "ё". Tracks also match on artist and album, so "кино группа
/// крови" finds the song. Results keep the library's sort order.
LibrarySearchResult searchLibrary(
  LibrarySnapshot library,
  String query, {
  int maxTracks = 50,
  int maxGroups = 20,
}) {
  final words = libraryKey(query)
      .split(' ')
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return const LibrarySearchResult();

  bool matches(Iterable<String?> fields) {
    final haystack = libraryKey(fields.whereType<String>().join(' '));
    return words.every(haystack.contains);
  }

  return LibrarySearchResult(
    tracks: sortTracks(library.tracks, TrackSort.title)
        .where(
          (t) => matches([t.title, t.artistName, t.albumArtist, t.albumTitle]),
        )
        .take(maxTracks)
        .toList(),
    albums: library.albums
        .where((a) => matches([a.title, a.artistName]))
        .take(maxGroups)
        .toList(),
    artists: library.artists
        .where((a) => matches([a.name]))
        .take(maxGroups)
        .toList(),
  );
}
