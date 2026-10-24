import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
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

    Widget tile(
      Track track, {
      required bool active,
      VoidCallback? onTap,
      Widget? trailing,
    }) {
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
        trailing:
            trailing ??
            (active
                ? Icon(
                    CupertinoIcons.speaker_2_fill,
                    size: AuraSizes.iconMd,
                    color: context.auraColors.accentText,
                  )
                : duration == null
                ? null
                : Text(formatDuration(duration), style: text.numeric)),
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
                    else if (controller == null)
                      SliverList.builder(
                        itemCount: upcoming.length,
                        itemBuilder: (context, i) =>
                            tile(upcoming[i], active: false),
                      )
                    else
                      _UpcomingList(
                        upcoming: upcoming,
                        firstIndex: currentIndex + 1,
                        controller: controller,
                        tile: tile,
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

/// The tracks after the current one: tap to play, drag the handle to
/// reorder, remove with the button. VoiceOver users get "move up/down"
/// actions instead of dragging.
class _UpcomingList extends StatelessWidget {
  const _UpcomingList({
    required this.upcoming,
    required this.firstIndex,
    required this.controller,
    required this.tile,
  });

  final List<Track> upcoming;

  /// Play-order index of [upcoming]'s first track.
  final int firstIndex;
  final PlaybackController controller;
  final Widget Function(
    Track track, {
    required bool active,
    VoidCallback? onTap,
    Widget? trailing,
  })
  tile;

  void _move(int from, int to) =>
      unawaited(controller.moveInQueue(firstIndex + from, firstIndex + to));

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    return SliverReorderableList(
      itemCount: upcoming.length,
      onReorderItem: (from, to) {
        if (to != from) _move(from, to);
      },
      proxyDecorator: (child, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AuraRadii.md),
        ),
        child: child,
      ),
      itemBuilder: (context, i) {
        final track = upcoming[i];
        return KeyedSubtree(
          key: ValueKey('upcoming-$i-${track.id.value}'),
          child: tile(
            track,
            active: false,
            onTap: () => unawaited(controller.skipToIndex(firstIndex + i)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuraIconButton(
                  icon: CupertinoIcons.minus_circle,
                  semanticLabel:
                      '${AuraStrings.removeFromQueue}: ${track.title}',
                  color: colors.textSecondary,
                  onPressed: () =>
                      unawaited(controller.removeFromQueue(firstIndex + i)),
                ),
                ReorderableDragStartListener(
                  index: i,
                  // The reorder control: VoiceOver users move the track
                  // with these actions instead of dragging.
                  child: Semantics(
                    container: true,
                    label: '${AuraStrings.reorderInQueue}: ${track.title}',
                    customSemanticsActions: {
                      if (i > 0)
                        const CustomSemanticsAction(
                          label: AuraStrings.moveUp,
                        ): () =>
                            _move(i, i - 1),
                      if (i < upcoming.length - 1)
                        const CustomSemanticsAction(
                          label: AuraStrings.moveDown,
                        ): () =>
                            _move(i, i + 1),
                    },
                    child: SizedBox.square(
                      dimension: AuraSizes.minTouchTarget,
                      child: Icon(
                        CupertinoIcons.line_horizontal_3,
                        color: colors.textSecondary,
                        size: AuraSizes.iconMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
