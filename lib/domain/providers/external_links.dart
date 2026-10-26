/// Opens a track's page in the provider's own app or site.
abstract interface class ExternalLinkOpener {
  /// False when nothing could open [uri] (or it was refused as unsafe).
  Future<bool> open(Uri uri);
}

/// Links from providers are untrusted data: only plain HTTPS web pages are
/// opened, never other schemes (which could start arbitrary apps) or URLs
/// with credentials.
bool isSafeExternalLink(Uri uri) =>
    uri.isScheme('https') && uri.host.isNotEmpty && uri.userInfo.isEmpty;

/// Where the share sheet points from on iPad (the tapped control), in
/// logical pixels of the screen.
typedef ShareOrigin = ({double left, double top, double width, double height});

/// Hands a link to the system share sheet (Messages, Telegram, copy...).
abstract interface class LinkSharer {
  /// False when the sheet could not be shown or [uri] is not a safe link.
  Future<bool> share({required String text, Uri? uri, ShareOrigin? origin});
}
