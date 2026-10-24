/// A SoundCloud page the user saved: a track, a playlist ("set"), a
/// profile, or a profile's likes. Only this URL is stored; everything
/// shown about it is loaded again each session (SoundCloud API terms).
final class SoundCloudLink {
  const SoundCloudLink._(this.url);

  /// Normalized `https://soundcloud.com/...` (or an `on.soundcloud.com`
  /// short link), without query or fragment. A private link keeps its
  /// secret token, which is part of the path (`/s-AbC12`).
  final Uri url;

  static const _hosts = {
    'soundcloud.com',
    'www.soundcloud.com',
    'm.soundcloud.com',
  };
  static const _shortHost = 'on.soundcloud.com';

  /// Pages that are not music (or need a SoundCloud login).
  static const _notMusic = {
    'discover',
    'search',
    'upload',
    'you',
    'charts',
    'stream',
    'settings',
    'messages',
    'notifications',
    'pages',
    'terms-of-use',
    'imprint',
    'pro',
    'popular',
    'signin',
    'logout',
    'jobs',
    'mobile',
    'people',
  };

  /// The link in [input] (a pasted URL, possibly with spaces, tracking
  /// parameters or `http:`), or null when it is not a SoundCloud music
  /// page.
  static SoundCloudLink? parse(String input) {
    var text = input.trim();
    if (text.isEmpty || text.length > 2048) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    if (uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443 && uri.port != 80)) {
      return null;
    }
    final host = uri.host.toLowerCase();
    final segments = [
      for (final s in uri.pathSegments)
        if (s.isNotEmpty) s,
    ];
    if (segments.isEmpty) return null;

    if (host == _shortHost) {
      return SoundCloudLink._(
        Uri(scheme: 'https', host: _shortHost, pathSegments: segments),
      );
    }
    if (!_hosts.contains(host)) return null;
    if (_notMusic.contains(segments.first.toLowerCase())) return null;
    return SoundCloudLink._(
      Uri(scheme: 'https', host: 'soundcloud.com', pathSegments: segments),
    );
  }

  /// SoundCloud's official embedded player for this page. Compact, no
  /// autoplay; AURA starts it on the user's tap.
  Uri get widgetUrl => Uri.https('w.soundcloud.com', '/player/', {
    'url': url.toString(),
    'auto_play': 'false',
    'visual': 'false',
    'show_comments': 'false',
    'show_reposts': 'false',
    'hide_related': 'true',
    'show_teaser': 'true',
  });

  @override
  bool operator ==(Object other) => other is SoundCloudLink && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'SoundCloudLink($url)';
}
