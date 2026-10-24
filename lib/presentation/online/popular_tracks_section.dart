import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/online/online_tracks.dart';

/// "Хиты недели" and "Популярное сейчас" on Home: real tracks from every provider with a
/// popular list, mixed. Hidden when there is no such provider.
class PopularTracksSection extends ConsumerWidget {
  const PopularTracksSection({super.key});

  static const _maxItems = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularTracksProvider);
    final value = popular.value;
    final error = popular.error;

    final Widget content;
    if (value != null) {
      if (value.isEmpty) return const SizedBox.shrink();
      final tracks = value.take(_maxItems).toList();
      final playable = tracks.where(canPlayInApp).toList();
      final cover = playable.firstOrNull ?? tracks.first;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.screenHorizontal,
            ),
            child: _HitsCard(
              trackCount: tracks.length,
              image: artworkImage(
                ref,
                cover.artworkUri,
                alternatives: cover.artworkAlternatives,
              ),
              seed: cover.title,
              onPlay: playable.isEmpty
                  ? null
                  : () => unawaited(
                      playOnline(context, ref, tracks, playable.first),
                    ),
            ),
          ),
          const SizedBox(height: AuraSpacing.sectionGap),
          const AuraSectionHeader(title: AuraStrings.popularNow),
          const SizedBox(height: AuraSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.screenHorizontal,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, track) in tracks.indexed) ...[
                  if (index > 0) const SizedBox(width: AuraSpacing.md),
                  AuraMediaCard(
                    title: track.title,
                    subtitle: canPlayInApp(track)
                        ? track.artistName ?? AuraStrings.unknownArtist
                        : AuraStrings.onlyInOriginal,
                    image: artworkImage(
                      ref,
                      track.artworkUri,
                      alternatives: track.artworkAlternatives,
                    ),
                    onPressed: () =>
                        unawaited(playOnline(context, ref, tracks, track)),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else if (error != null && !popular.isLoading) {
      final (errorTitle, message) = failureText(error);
      content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpacing.screenHorizontal,
        ),
        child: _InlineError(
          title: errorTitle,
          message: message,
          onRetry: () => ref.invalidate(popularTracksProvider),
        ),
      );
    } else if (popular.isLoading) {
      content = const SizedBox(
        height: _HitsCard.height,
        child: AuraLoadingState(label: AuraStrings.loading),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [content],
      ),
    );
  }
}

/// "Хиты недели": the top of the popular list as a large card over the
/// first cover, with a button that plays the whole list.
class _HitsCard extends StatelessWidget {
  const _HitsCard({
    required this.trackCount,
    required this.image,
    required this.seed,
    required this.onPlay,
  });

  static const height = 184.0;

  final int trackCount;
  final ImageProvider<Object>? image;
  final String seed;

  /// Null when nothing in the list can play here.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final onPlay = this.onPlay;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: height),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuraRadii.xl),
        child: Stack(
          children: [
            Positioned.fill(
              child: AuraArtworkBackdrop(image: image, placeholderSeed: seed),
            ),
            // Scrim: strongest on the left, where the text is.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colors.background.withValues(alpha: 0.88),
                      colors.background.withValues(alpha: 0.55),
                      colors.background.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, 0.9),
                    radius: 1.1,
                    colors: [
                      colors.accent.withValues(alpha: 0.28),
                      colors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AuraSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AuraSpacing.huge),
                          Text(
                            AuraStrings.weeklyHits,
                            style: text.largeTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AuraSpacing.xs),
                          Text(
                            AuraStrings.weeklyHitsSubtitle(trackCount),
                            style: text.subhead.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onPlay != null) ...[
                    const SizedBox(width: AuraSpacing.md),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: colors.accentGlow,
                      ),
                      child: AuraIconButton.filled(
                        icon: CupertinoIcons.play_fill,
                        semanticLabel: AuraStrings.playPlaylist(
                          AuraStrings.weeklyHits,
                        ),
                        diameter: 56,
                        onPressed: onPlay,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact failure with a retry button, for one section of a screen.
class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headline),
          const SizedBox(height: AuraSpacing.xxs),
          Text(message, style: text.subhead),
          const SizedBox(height: AuraSpacing.md),
          AuraButton(
            label: AuraStrings.retry,
            variant: AuraButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Exposed for the search screen's per-provider errors.
class InlineErrorBox extends StatelessWidget {
  const InlineErrorBox({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = failureText(error);
    return _InlineError(title: title, message: message, onRetry: onRetry);
  }
}
