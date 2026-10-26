import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/application/playback/listening_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/content_width.dart';
import 'package:music_app/presentation/common/duration_format.dart';
import 'package:music_app/presentation/library/history_screen.dart';
import 'package:music_app/presentation/library/track_menu.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/mixed_track_list.dart';

enum _QueueTab { current, recent }

/// "Текущая": the current track and what plays next, in play order (tap
/// to jump, drag to reorder, clear what is left). "Недавние": what was
/// played lately, to play again.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  var _tab = _QueueTab.current;

  /// The whole queue into a playlist (new or existing), online tracks
  /// included.
  Future<void> _saveQueue(List<Track> queue) async {
    final result = await addTracksToPlaylist(
      context,
      ref,
      queue,
      title: AuraStrings.saveQueueAsPlaylist,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        await showMessage(
          context,
          title: AuraStrings.savedToPlaylist(queue.length),
          message: AuraStrings.savedToPlaylistHint,
        );
      case Err(:final failure):
        await showFailure(context, failure);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.auraText;
    final queue =
        ref.watch(playbackSnapshotProvider).value?.queue ?? const <Track>[];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              // Pinned like an iOS navigation bar: never scrolls away.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
                child: Row(
                  children: [
                    AuraIconButton(
                      icon: CupertinoIcons.chevron_left,
                      semanticLabel: AuraStrings.back,
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                    if (queue.isNotEmpty)
                      AuraIconButton(
                        icon: CupertinoIcons.text_badge_plus,
                        semanticLabel: AuraStrings.saveQueueAsPlaylist,
                        color: context.auraColors.textSecondary,
                        onPressed: () => unawaited(_saveQueue(queue)),
                      ),
                  ],
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AuraSpacing.screenHorizontal,
                          AuraSpacing.lg,
                          AuraSpacing.screenHorizontal,
                          0,
                        ),
                        child: AuraSegmentedControl<_QueueTab>(
                          segments: const [
                            (_QueueTab.current, AuraStrings.queueCurrent),
                            (_QueueTab.recent, AuraStrings.queueRecent),
                          ],
                          selected: _tab,
                          onSelected: (tab) => setState(() => _tab = tab),
                        ),
                      ),
                    ),
                    ...switch (_tab) {
                      _QueueTab.current => _currentSlivers(context),
                      _QueueTab.recent => _recentSlivers(),
                    },
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

  List<Widget> _currentSlivers(BuildContext context) {
    final snapshot =
        ref.watch(playbackSnapshotProvider).value ?? PlaybackSnapshot.initial;
    final controller = ref.watch(playbackControllerProvider);
    final current = snapshot.currentTrack;
    final currentIndex = snapshot.currentIndex ?? -1;
    final upcoming = snapshot.queue.skip(currentIndex + 1).toList();
    final colors = context.auraColors;
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
            (duration == null
                ? null
                : Text(formatDuration(duration), style: text.numeric)),
        onPressed: onTap,
      );
    }

    Future<void> clearUpcoming() async {
      // From the end, so the indexes still to remove do not shift.
      for (var i = snapshot.queue.length - 1; i > currentIndex; i--) {
        await controller!.removeFromQueue(i);
      }
    }

    return [
      if (current != null) ...[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: AuraSpacing.xxl,
              bottom: AuraSpacing.sm,
            ),
            child: AuraSectionHeader(title: AuraStrings.nowPlaying),
          ),
        ),
        // The current track on its own highlighted card.
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AuraSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(AuraRadii.lg),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: tile(
                current,
                active: true,
                trailing: _PlayingIndicator(playing: snapshot.playWhenReady),
              ),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: AuraSpacing.xl),
          child: upcoming.isEmpty || controller == null
              ? const AuraSectionHeader(title: AuraStrings.upNext)
              : AuraSectionHeader(
                  title: AuraStrings.upNext,
                  actionLabel: AuraStrings.clear,
                  onAction: () => unawaited(clearUpcoming()),
                ),
        ),
      ),
      if (upcoming.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpacing.screenHorizontal,
              vertical: AuraSpacing.md,
            ),
            child: Text(AuraStrings.queueEnd, style: text.subhead),
          ),
        )
      else if (controller == null)
        SliverList.builder(
          itemCount: upcoming.length,
          itemBuilder: (context, i) => tile(upcoming[i], active: false),
        )
      else
        _UpcomingList(
          upcoming: upcoming,
          firstIndex: currentIndex + 1,
          controller: controller,
          tile: tile,
        ),
    ];
  }

  List<Widget> _recentSlivers() {
    final recent = ref.watch(recentlyPlayedProvider);
    final value = recent.value;
    if (value == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AuraSpacing.lg),
            child: recent.error == null
                ? const LoadingRow()
                : InlineErrorText(error: recent.error!),
          ),
        ),
      ];
    }
    if (value.tracks.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: AuraSpacing.xxl),
            child: AuraEmptyState(
              icon: historyIcon,
              title: AuraStrings.historyEmptyTitle,
              message: AuraStrings.historyEmptyMessage,
            ),
          ),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(child: SizedBox(height: AuraSpacing.md)),
      MixedTrackListSliver(tracks: value.tracks),
      SliverToBoxAdapter(
        child: ResolvedListFooter(
          resolved: value,
          onRetry: () => ref.invalidate(recentlyPlayedProvider),
        ),
      ),
    ];
  }
}

/// Moving bars while the current track plays, still bars while paused.
/// Driven by the playback position, so only this widget rebuilds.
class _PlayingIndicator extends ConsumerWidget {
  const _PlayingIndicator({required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(playbackPositionProvider).value ?? Duration.zero;
    return Padding(
      padding: const EdgeInsets.only(right: AuraSpacing.xs),
      child: AuraEqualizer(active: playing, phase: position),
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
