import 'package:flutter/cupertino.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// Compact player above the tab bar. Shown only while a track is loaded.
/// Expanding into Now Playing comes in Phase 5.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.onTogglePlay,
  });

  final Track track;
  final bool isPlaying;

  /// Null disables the button.
  final VoidCallback? onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.sm,
        0,
        AuraSpacing.sm,
        AuraSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AuraRadii.md),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AuraSizes.miniPlayerHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
            child: Row(
              children: [
                AuraArtwork(
                  size: 44,
                  image: null,
                  placeholderSeed: track.title,
                ),
                const SizedBox(width: AuraSpacing.md),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          style: text.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artistName ?? AuraStrings.unknownArtist,
                          style: text.subhead,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                AuraIconButton(
                  icon: isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  semanticLabel: isPlaying
                      ? AuraStrings.pause
                      : AuraStrings.play,
                  onPressed: onTogglePlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
