import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/network/json_http_client.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';

/// What SoundCloud says about a saved page: its title, author and cover.
final class SoundCloudPageInfo {
  const SoundCloudPageInfo({required this.title, this.author, this.artwork});

  final String title;
  final String? author;
  final Uri? artwork;
}

/// SoundCloud's public oEmbed endpoint: no key, no account. Used only to
/// label saved links; never stored (session use only).
final class SoundCloudOEmbed {
  SoundCloudOEmbed(this._http);

  final JsonHttpClient _http;

  Future<Result<SoundCloudPageInfo>> info(SoundCloudLink link) async {
    final response = await _http.getJson(
      Uri.https('soundcloud.com', '/oembed', {
        'format': 'json',
        'url': link.url.toString(),
      }),
    );
    switch (response) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value is! Map<String, Object?>) return const Err(_invalid);
        final title = value['title'];
        if (title is! String || title.trim().isEmpty) {
          return const Err(_invalid);
        }
        final author = value['author_name'];
        final thumbnail = value['thumbnail_url'];
        final artwork = thumbnail is String ? Uri.tryParse(thumbnail) : null;
        return Ok(
          SoundCloudPageInfo(
            title: title.trim(),
            author: author is String && author.trim().isNotEmpty
                ? author.trim()
                : null,
            artwork: artwork != null && artwork.isScheme('https')
                ? artwork
                : null,
          ),
        );
    }
  }

  static const _invalid = InvalidResponseFailure(
    debugMessage: 'SoundCloud oEmbed without title',
  );
}
