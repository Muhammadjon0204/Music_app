import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/playlist.dart';

/// Content of the Home screen.
final class HomeFeed {
  HomeFeed({
    required List<Album> recentlyPlayed,
    required List<Album> albums,
    required List<Playlist> playlists,
    this.featured,
    this.isDemo = false,
  }) : recentlyPlayed = List.unmodifiable(recentlyPlayed),
       albums = List.unmodifiable(albums),
       playlists = List.unmodifiable(playlists);

  final Playlist? featured;
  final List<Album> recentlyPlayed;
  final List<Album> albums;
  final List<Playlist> playlists;

  /// True when this is sample content rather than the user's library.
  /// The UI must label it as such.
  final bool isDemo;

  bool get isEmpty =>
      featured == null &&
      recentlyPlayed.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is HomeFeed &&
      other.featured == featured &&
      elementsEqual(other.recentlyPlayed, recentlyPlayed) &&
      elementsEqual(other.albums, albums) &&
      elementsEqual(other.playlists, playlists) &&
      other.isDemo == isDemo;

  @override
  int get hashCode => Object.hash(
    featured,
    Object.hashAll(recentlyPlayed),
    Object.hashAll(albums),
    Object.hashAll(playlists),
    isDemo,
  );
}

abstract interface class HomeFeedSource {
  Future<Result<HomeFeed>> load();
}
