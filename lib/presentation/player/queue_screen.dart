import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

/// The current track and what plays next, in play order. Tapping a track
/// jumps to it.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot =
        ref.watch(playbackSnapshotProvider).value ?? PlaybackSnapshot.initial;
    final controller = ref.watch(playbackControllerProvider);
    final current = snapshot.currentTrack;
    final currentIndex = snapshot.currentIndex ?? -1;
    final upcoming = snapshot.queue.skip(currentIndex + 1).toList();
    final text = context.auraText;

    Widget tile(Track track, {required bool active, VoidCallback? onTap}) {
      final duration = track.duration;
      return AuraListTile(
        title: track.title,
        subtitle: track.artistName ?? AuraStrings.unknownArtist,
        isActive: active,
        leading: AuraArtwork(
          size: AuraSizes.artworkListTile,
          image: artworkImage(
            ref,
            track.artworkUri,
            alternatives: track.artworkAlternatives,
          ),
          placeholderSeed: track.title,
        ),
        trailing: active
            ? Icon(
                CupertinoIcons.speaker_2_fill,
                size: AuraSizes.iconMd,
                color: context.auraColors.accentText,
              )
            : duration == null
            ? null
            : Text(formatDuration(duration), style: text.numeric),
        onPressed: onTap,
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              // Pinned like an iOS navigation bar: never scrolls away.
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: AuraSpacing.sm),
                  child: AuraIconButton(
                    icon: CupertinoIcons.chevron_left,
                    semanticLabel: AuraStrings.back,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpacing.screenHorizontal,
                        ),
                        child: Semantics(
                          header: true,
                          child: Text(
                            AuraStrings.queue,
                            style: text.largeTitle,
                          ),
                        ),
                      ),
                    ),
                    if (current != null) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: AuraSpacing.xxl),
                          child: AuraSectionHeader(
                            title: AuraStrings.nowPlaying,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: tile(current, active: true)),
                    ],
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: AuraSpacing.xxl),
                        child: AuraSectionHeader(title: AuraStrings.upNext),
                      ),
                    ),
                    if (upcoming.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpacing.screenHorizontal,
                            vertical: AuraSpacing.md,
                          ),
                          child: Text(
                            AuraStrings.queueEnd,
                            style: text.subhead,
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: upcoming.length,
                        itemBuilder: (context, i) => tile(
                          upcoming[i],
                          active: false,
                          onTap: controller == null
                              ? null
                              : () => unawaited(
                                  controller.skipToIndex(currentIndex + 1 + i),
                                ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            AuraSpacing.xxxl +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
