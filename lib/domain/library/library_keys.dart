import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';

/// Normalized form used for grouping and sorting: case-insensitive,
/// whitespace-collapsed, and "ё" treated as "е" (Russian collation).
String libraryKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Groups a track into an album: same album title by the same artist.
/// Null when the track has no album tag.
AlbumId? albumKeyOf(Track track) {
  final album = track.albumTitle;
  if (album == null || album.trim().isEmpty) return null;
  return AlbumId(
    '${libraryKey(track.primaryArtist ?? '')}\u001f${libraryKey(album)}',
  );
}

/// Groups a track under its primary artist. Null when unknown.
ArtistId? artistKeyOf(Track track) {
  final artist = track.primaryArtist;
  if (artist == null || artist.trim().isEmpty) return null;
  return ArtistId(libraryKey(artist));
}

/// Compares display strings the way people expect: case- and
/// "ё"-insensitive; missing values sort last.
int compareLibraryText(String? a, String? b) {
  if (a == null || a.trim().isEmpty) {
    return b == null || b.trim().isEmpty ? 0 : 1;
  }
  if (b == null || b.trim().isEmpty) return -1;
  return libraryKey(a).compareTo(libraryKey(b));
}
