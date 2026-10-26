import 'dart:ui';

import 'package:music_app/domain/providers/external_links.dart';
import 'package:share_plus/share_plus.dart';

/// The system share sheet through share_plus. Only safe HTTPS links are
/// shared; the text says what the link is.
final class SharePlusLinkSharer implements LinkSharer {
  const SharePlusLinkSharer();

  @override
  Future<bool> share({
    required String text,
    Uri? uri,
    ShareOrigin? origin,
  }) async {
    if (uri != null && !isSafeExternalLink(uri)) return false;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: uri == null ? text : '$text\n$uri',
          sharePositionOrigin: origin == null
              ? null
              : Rect.fromLTWH(
                  origin.left,
                  origin.top,
                  origin.width,
                  origin.height,
                ),
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } on Object {
      return false;
    }
  }
}
