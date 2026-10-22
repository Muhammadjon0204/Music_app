abstract final class AppRoutes {
  static const home = '/home';
  static const search = '/search';
  static const library = '/library';

  static const libraryTracks = '/library/tracks';
  static const libraryFavorites = '/library/favorites';
  static const libraryAlbums = '/library/albums';
  static const libraryArtists = '/library/artists';
  static const libraryPlaylists = '/library/playlists';

  /// Full-screen player above the tabs.
  static const nowPlaying = '/player';
  static const queue = '/player/queue';

  /// Debug builds only.
  static const devGallery = '/home/dev-gallery';

  /// Opens the Search tab with the field focused. [token] must differ per
  /// request so repeated taps refocus.
  static String searchFocused(String token) => '$search?focus=$token';

  /// Album, artist or playlist page inside a tab (`/home`, `/search` or
  /// `/library`), so it opens in that tab's own history.
  static String detail(String tabRoot, DetailKind kind, String id) =>
      '$tabRoot/${kind.name}/${Uri.encodeComponent(id)}';
}

enum DetailKind { album, artist, playlist }
