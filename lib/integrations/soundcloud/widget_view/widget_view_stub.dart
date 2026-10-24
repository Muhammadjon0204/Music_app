import 'package:flutter/widgets.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_link.dart';
import 'package:music_app/integrations/soundcloud/soundcloud_player_controller.dart';

/// No embedded player on this platform.
bool get soundCloudWidgetSupported => false;

Widget buildSoundCloudWidget({
  required SoundCloudLink link,
  required SoundCloudPlayerController controller,
}) => const SizedBox.shrink();
