import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_track_tile.dart';
import 'package:music_app/presentation/library/track_menu.dart';
import 'package:music_app/presentation/online/online_tracks.dart';
import 'package:music_app/presentation/online/popular_tracks_section.dart';

/// Library and online tracks in one list (history, favorites): each row
/// behaves like it does elsewhere; playing a row queues the whole list.
class MixedTrackListSliver extends ConsumerWidget {
  const MixedTrackListSliver({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(
      playbackSnapshotProvider.select((s) => s.value?.currentTrack?.id),
    );
    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        if (onlineSourceOf(track) != null) {
          return OnlineTrackTile(track: track, list: tracks);
        }
        return LibraryTrackTile(
          track: track,
          isCurrent: track.id == currentId,
          onPressed: () => unawaited(playOnline(context, ref, tracks, track)),
          onMore: () => unawaited(showTrackMenu(context, ref, track)),
        );
      },
    );
  }
}

/// What could not be shown of a resolved list: a lookup failure with retry
/// (e.g. offline), and how many saved tracks no longer exist.
class ResolvedListFooter extends ConsumerWidget {
  const ResolvedListFooter({
    super.key,
    required this.resolved,
    required this.onRetry,
  });

  final ResolvedTracks resolved;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = resolved.failure;
    final unavailable = resolved.unavailable;
    if (failure == null && unavailable == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpacing.screenHorizontal,
        vertical: AuraSpacing.md,
      ),
      child: failure != null
          ? InlineErrorBox(error: failure, onRetry: onRetry)
          : Text(
              AuraStrings.savedUnavailable(unavailable),
              style: context.auraText.subhead,
            ),
    );
  }
}

/// A loading row for a list section that is still being resolved.
class LoadingRow extends StatelessWidget {
  const LoadingRow({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: AuraSizes.listTileMinHeight,
    child: AuraLoadingState(label: AuraStrings.loading),
  );
}

/// Icon used for listening history.
const historyIcon = CupertinoIcons.time;
