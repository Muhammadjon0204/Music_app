import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/online/online_tracks.dart';

/// "Недавно прослушанные" on Home: real listening history (library and
/// online tracks). Hidden until something has been listened to.
class RecentlyPlayedSection extends ConsumerWidget {
  const RecentlyPlayedSection({super.key});

  static const _maxItems = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref
        .watch(recentlyPlayedProvider)
        .value
        ?.tracks
        .take(_maxItems)
        .toList();
    if (tracks == null || tracks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraSectionHeader(
            title: AuraStrings.recentlyPlayed,
            actionLabel: AuraStrings.history,
            // History lives in the Library tab.
            onAction: () => context.go(AppRoutes.libraryHistory),
          ),
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
                    subtitle: track.artistName ?? AuraStrings.unknownArtist,
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
      ),
    );
  }
}
