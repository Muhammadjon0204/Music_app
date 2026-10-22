import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/failure_text.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/online/online_tracks.dart';

/// "Популярное в Audius" on Home: real tracks from the first provider with
/// a popular list. Hidden when there is no such provider.
class PopularTracksSection extends ConsumerWidget {
  const PopularTracksSection({super.key});

  static const _maxItems = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularTracksProvider);
    final value = popular.value;
    final error = popular.error;

    final Widget content;
    String? title;
    if (value != null) {
      if (value.tracks.isEmpty) return const SizedBox.shrink();
      title = AuraStrings.popularIn(value.providerName);
      final tracks = value.tracks.take(_maxItems).toList();
      content = SingleChildScrollView(
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
                    : AuraStrings.onlyIn(value.providerName),
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
        height: AuraSizes.artworkCard + 48,
        child: AuraLoadingState(label: AuraStrings.loading),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            AuraSectionHeader(title: title),
            const SizedBox(height: AuraSpacing.md),
          ],
          content,
        ],
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
