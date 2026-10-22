import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/album.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';

/// What the featured banner shows. Non-playlist kinds are named by the UI.
enum HomeFeaturedKind { playlist, favorites, allTracks }

/// Content of the Home screen.
final class HomeFeed {
  HomeFeed({
    required List<Album> recentlyAdded,
    required List<Album> albums,
    required List<Playlist> playlists,
    this.featured,
    this.featuredKind = HomeFeaturedKind.playlist,
    List<Track> featuredTracks = const [],
    this.isDemo = false,
  }) : recentlyAdded = List.unmodifiable(recentlyAdded),
       albums = List.unmodifiable(albums),
       playlists = List.unmodifiable(playlists),
       featuredTracks = List.unmodifiable(featuredTracks);

  final Playlist? featured;
  final HomeFeaturedKind featuredKind;

  /// The featured playlist's tracks, so it can be played from Home.
  final List<Track> featuredTracks;
  final List<Album> recentlyAdded;
  final List<Album> albums;
  final List<Playlist> playlists;

  /// True when this is sample content rather than the user's library.
  /// The UI must label it as such.
  final bool isDemo;

  bool get isEmpty =>
      featured == null &&
      recentlyAdded.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is HomeFeed &&
      other.featured == featured &&
      other.featuredKind == featuredKind &&
      elementsEqual(other.featuredTracks, featuredTracks) &&
      elementsEqual(other.recentlyAdded, recentlyAdded) &&
      elementsEqual(other.albums, albums) &&
      elementsEqual(other.playlists, playlists) &&
      other.isDemo == isDemo;

  @override
  int get hashCode => Object.hash(
    featured,
    featuredKind,
    Object.hashAll(featuredTracks),
    Object.hashAll(recentlyAdded),
    Object.hashAll(albums),
    Object.hashAll(playlists),
    isDemo,
  );
}

abstract interface class HomeFeedSource {
  Future<Result<HomeFeed>> load();
}
