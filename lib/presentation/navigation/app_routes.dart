abstract final class AppRoutes {
  static const home = '/home';
  static const search = '/search';
  static const library = '/library';

  static const libraryTracks = '/library/tracks';
  static const libraryFavorites = '/library/favorites';
  static const libraryAlbums = '/library/albums';
  static const libraryArtists = '/library/artists';
  static const libraryPlaylists = '/library/playlists';
  static const libraryHistory = '/library/history';
  static const librarySoundCloud = '/library/soundcloud';

  /// The official SoundCloud player for a saved [link] URL.
  static String soundCloudPlayer(Uri link) =>
      '$librarySoundCloud/player?url=${Uri.encodeQueryComponent('$link')}';

  /// Full-screen player above the tabs.
  static const nowPlaying = '/player';
  static const queue = '/player/queue';

  static const settings = '/settings';
  static const settingsSources = '/settings/sources';

  /// Debug builds only.
  static const devGallery = '/home/dev-gallery';

  /// Opens the Search tab with the field focused. [token] must differ per
  /// request so repeated taps refocus.
  static String searchFocused(String token) => '$search?focus=$token';

  /// Album, artist or playlist page inside a tab (`/home`, `/search` or
  /// `/library`), so it opens in that tab's own history.
  static String detail(String tabRoot, DetailKind kind, String id) =>
      '$tabRoot/${kind.name}/${Uri.encodeComponent(id)}';

  /// An online catalog's artist page inside a tab.
  static String onlineArtist(String tabRoot, String provider, String id) =>
      '$tabRoot/online-artist/${Uri.encodeComponent(provider)}/'
      '${Uri.encodeComponent(id)}';
}

enum DetailKind { album, artist, playlist }
