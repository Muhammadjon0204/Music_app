import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// A track row with artwork, "artist · duration", and a "more" button.
/// A missing file is shown in words, not only by dimming.
class LibraryTrackTile extends ConsumerWidget {
  const LibraryTrackTile({
    super.key,
    required this.track,
    required this.onPressed,
    this.onMore,
    this.missing = false,
    this.isCurrent = false,
  });

  final Track track;
  final VoidCallback onPressed;
  final VoidCallback? onMore;
  final bool missing;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = track.duration;
    final subtitle = missing
        ? AuraStrings.missingFile
        : [
            track.artistName ?? AuraStrings.unknownArtist,
            if (duration != null) formatDuration(duration),
          ].join(' · ');
    final onMore = this.onMore;

    return Opacity(
      opacity: missing ? 0.55 : 1,
      child: AuraListTile(
        title: track.title,
        subtitle: subtitle,
        isActive: isCurrent,
        leading: AuraArtwork(
          size: AuraSizes.artworkListTile,
          image: artworkImage(ref, track.artworkUri),
          placeholderSeed: track.title,
        ),
        trailing: onMore == null
            ? null
            : AuraIconButton(
                icon: CupertinoIcons.ellipsis,
                semanticLabel: '${AuraStrings.more}: ${track.title}',
                color: context.auraColors.textSecondary,
                onPressed: onMore,
              ),
        onPressed: onPressed,
      ),
    );
  }
}
