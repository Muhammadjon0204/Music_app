abstract final class AppRoutes {
  static const home = '/home';
  static const search = '/search';
  static const library = '/library';

  /// Full-screen player above the tabs.
  static const nowPlaying = '/player';
  static const queue = '/player/queue';

  /// Debug builds only.
  static const devGallery = '/home/dev-gallery';

  /// Opens the Search tab with the field focused. [token] must differ per
  /// request so repeated taps refocus.
  static String searchFocused(String token) => '$search?focus=$token';
}
