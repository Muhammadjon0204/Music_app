import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/player/play_pause_button.dart';
import 'package:music_app/presentation/player/player_palette.dart';

/// Compact player above the tab bar, shown while a track is loaded.
/// Tapping the artwork/title opens Now Playing; the buttons stay separate
/// so VoiceOver can reach each of them.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({
    super.key,
    required this.track,
    required this.isPlaying,
    this.isWaiting = false,
    required this.onTogglePlay,
    required this.onNext,
    required this.onOpen,
    required this.progress,
  });

  final Track track;
  final bool isPlaying;
  final bool isWaiting;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNext;
  final VoidCallback? onOpen;

  /// Thin progress line, rebuilt on its own.
  final Widget progress;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadii.md),
        child: ColoredBox(
          color: colors.surfaceElevated,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AuraSizes.miniPlayerHeight - 2,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AuraPressable(
                          onPressed: onOpen,
                          semanticLabel: AuraStrings.openPlayer,
                          feedback: AuraPressFeedback.opacity,
                          child: Row(
                            children: [
                              HeroMode(
                                enabled: !AuraMotion.isReduced(context),
                                child: Hero(
                                  tag: playerArtworkHeroTag,
                                  child: Consumer(
                                    builder: (_, ref, _) => AuraArtwork(
                                      size: 44,
                                      image: artworkImage(
                                        ref,
                                        track.artworkUri,
                                        alternatives: track.artworkAlternatives,
                                      ),
                                      placeholderSeed: track.title,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AuraSpacing.md),
                              Expanded(
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
                                      track.artistName ??
                                          AuraStrings.unknownArtist,
                                      style: text.subhead,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PlayPauseButton(
                        isPlaying: isPlaying,
                        isWaiting: isWaiting,
                        onPressed: onTogglePlay,
                      ),
                      AuraIconButton(
                        icon: CupertinoIcons.forward_fill,
                        semanticLabel: AuraStrings.nextTrack,
                        haptic: true,
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ),
              ),
              progress,
            ],
          ),
        ),
      ),
    );
  }
}
