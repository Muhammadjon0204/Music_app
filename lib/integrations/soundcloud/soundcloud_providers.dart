import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link_store.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_oembed.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_widget_view.dart';

/// Builds the official embedded player, or null where there is none (the
/// screen then offers "Open in SoundCloud"). Replaced in tests.
typedef SoundCloudWidgetBuilder = Widget Function(
  SoundCloudLink link,
  SoundCloudPlayerController controller,
);

final soundCloudWidgetBuilderProvider = Provider<SoundCloudWidgetBuilder?>(
  (ref) => soundCloudWidgetSupported
      ? (link, controller) =>
            buildSoundCloudWidget(link: link, controller: controller)
      : null,
);

/// Bound at the composition root; null hides SoundCloud (tests).
final soundCloudLinkStoreProvider = Provider<SoundCloudLinkStore?>(
  (ref) => null,
);

final soundCloudOEmbedProvider = Provider<SoundCloudOEmbed?>((ref) => null);

/// Saved links, newest first.
final soundCloudLinksProvider = StreamProvider<List<SoundCloudLink>>((ref) {
  final store = ref.watch(soundCloudLinkStoreProvider);
  return store?.watch() ?? Stream.value(const []);
}, retry: (_, _) => null);

/// Title, author and cover of a saved link, for this session only.
final soundCloudInfoProvider =
    FutureProvider.family<SoundCloudPageInfo?, SoundCloudLink>((
      ref,
      link,
    ) async {
      final oEmbed = ref.watch(soundCloudOEmbedProvider);
      if (oEmbed == null) return null;
      return switch (await oEmbed.info(link)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
    }, retry: (_, _) => null);
