import 'package:music_app/domain/library/library_keys.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/artist.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';

enum TrackSort { title, artist, recentlyAdded }

/// A consistent view of the user's library at one moment.
///
/// Albums and artists are derived from track tags, not stored. Every
/// emitted snapshot is a real change, so identity equality is sufficient.
final class LibrarySnapshot {
  LibrarySnapshot({
    required List<Track> tracks,
    List<TrackId> favoriteIds = const [],
    List<Playlist> playlists = const [],
  }) : tracks = List.unmodifiable(tracks),
       favoriteIds = List.unmodifiable(favoriteIds),
       playlists = List.unmodifiable(playlists);

  static final LibrarySnapshot empty = LibrarySnapshot(tracks: const []);

  final List<Track> tracks;

  /// Most recently favorited first.
  final List<TrackId> favoriteIds;
  final List<Playlist> playlists;

  bool get isEmpty => tracks.isEmpty;

  late final Map<TrackId, Track> _byId = {for (final t in tracks) t.id: t};
  late final Set<TrackId> _favorites = favoriteIds.toSet();

  Track? track(TrackId id) => _byId[id];

  bool contains(TrackId id) => _byId.containsKey(id);

  bool isFavorite(TrackId id) => _favorites.contains(id);

  /// Favorite tracks still in the library, most recent first.
  List<Track> get favorites => [for (final id in favoriteIds) ?_byId[id]];

  /// Favorite online tracks, most recent first. Stored as references only
  /// (provider + ID): their details are looked up when shown.
  List<TrackId> get onlineFavoriteIds => [
    for (final id in favoriteIds)
      if (!_byId.containsKey(id) && providerRefOf(id) != null) id,
  ];

  Playlist? playlist(PlaylistId id) {
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// A playlist's tracks that still exist, in playlist order.
  List<Track> tracksOf(Playlist playlist) => [
    for (final id in playlist.trackIds) ?_byId[id],
  ];

  List<Track> recentlyAdded({int limit = 10}) =>
      sortTracks(tracks, TrackSort.recentlyAdded).take(limit).toList();

  late final Map<AlbumId, List<Track>> _albumTracks = _group(albumKeyOf);
  late final Map<ArtistId, List<Track>> _artistTracks = _group(artistKeyOf);

  /// Albums from track tags, sorted by title. Untagged tracks are not
  /// grouped into an album (they stay in "all tracks").
  late final List<Album> albums = [
    for (final MapEntry(key: id, value: tracks) in _albumTracks.entries)
      Album(
        id: id,
        title: tracks.first.albumTitle!,
        artistName: tracks.first.primaryArtist,
        year: tracks.first.year,
        artworkUri: tracks
            .map((t) => t.artworkUri)
            .firstWhere((uri) => uri != null, orElse: () => null),
      ),
  ]..sort((a, b) => compareLibraryText(a.title, b.title));

  /// Artists from track tags, sorted by name.
  late final List<Artist> artists = [
    for (final MapEntry(key: id, value: tracks) in _artistTracks.entries)
      Artist(id: id, name: tracks.first.primaryArtist!),
  ]..sort((a, b) => compareLibraryText(a.name, b.name));

  Album? album(AlbumId id) {
    for (final album in albums) {
      if (album.id == id) return album;
    }
    return null;
  }

  Artist? artist(ArtistId id) {
    for (final artist in artists) {
      if (artist.id == id) return artist;
    }
    return null;
  }

  /// Album tracks in disc and track order.
  List<Track> albumTracks(AlbumId id) =>
      [...?_albumTracks[id]]..sort(_compareAlbumOrder);

  /// An artist's tracks grouped by album, then in album order.
  List<Track> artistTracks(ArtistId id) =>
      [...?_artistTracks[id]]..sort((a, b) {
        final byAlbum = compareLibraryText(a.albumTitle, b.albumTitle);
        return byAlbum != 0 ? byAlbum : _compareAlbumOrder(a, b);
      });

  Map<K, List<Track>> _group<K>(K? Function(Track) keyOf) {
    final groups = <K, List<Track>>{};
    for (final track in tracks) {
      final key = keyOf(track);
      if (key != null) (groups[key] ??= []).add(track);
    }
    return groups;
  }

  static int _compareAlbumOrder(Track a, Track b) {
    final disc = (a.discNumber ?? 1).compareTo(b.discNumber ?? 1);
    if (disc != 0) return disc;
    final number = (a.trackNumber ?? 1 << 20).compareTo(
      b.trackNumber ?? 1 << 20,
    );
    return number != 0 ? number : compareLibraryText(a.title, b.title);
  }
}

/// Sorted copy of [tracks]. Stable for equal keys.
List<Track> sortTracks(List<Track> tracks, TrackSort sort) {
  final indexed = tracks.indexed.toList();
  int compare((int, Track) a, (int, Track) b) {
    final (ia, ta) = a;
    final (ib, tb) = b;
    final result = switch (sort) {
      TrackSort.title => compareLibraryText(ta.title, tb.title),
      TrackSort.artist => () {
        final byArtist = compareLibraryText(ta.artistName, tb.artistName);
        return byArtist != 0
            ? byArtist
            : compareLibraryText(ta.title, tb.title);
      }(),
      TrackSort.recentlyAdded => (tb.addedAt ?? DateTime(0)).compareTo(
        ta.addedAt ?? DateTime(0),
      ),
    };
    return result != 0 ? result : ia.compareTo(ib);
  }

  indexed.sort(compare);
  return [for (final (_, track) in indexed) track];
}
