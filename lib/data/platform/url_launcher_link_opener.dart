import 'package:music_app/domain/providers/external_links.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens links with the system: the provider's app when it handles the
/// link (iOS universal links), the browser otherwise.
final class UrlLauncherLinkOpener implements ExternalLinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri uri) async {
    if (!isSafeExternalLink(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // No handler, or the platform refused: reported as "could not open".
      return false;
    }
  }
}
