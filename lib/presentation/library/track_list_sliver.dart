import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/play_tracks.dart';
import 'package:music_app/presentation/library/library_track_tile.dart';
import 'package:music_app/presentation/library/track_menu.dart';

/// Library tracks as a lazy list. Tapping plays the list from that track,
/// skipping tracks whose file is missing.
class TrackListSliver extends ConsumerWidget {
  const TrackListSliver({super.key, required this.tracks, this.playlistId});

  final List<Track> tracks;

  /// Set when [tracks] is a playlist, adding "remove from playlist".
  final PlaylistId? playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingTracksProvider).value ?? const {};
    final currentId = ref.watch(
      playbackSnapshotProvider.select((s) => s.value?.currentTrack?.id),
    );
    final playlistId = this.playlistId;

    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isMissing = missing.contains(track.id);
        return LibraryTrackTile(
          track: track,
          missing: isMissing,
          isCurrent: track.id == currentId,
          onPressed: () {
            if (isMissing) {
              unawaited(showMissingTrack(context, ref, track));
              return;
            }
            final playable = playableTracks(ref, tracks);
            unawaited(
              playTracks(ref, playable, index: playable.indexOf(track)),
            );
          },
          onMore: () => unawaited(
            showTrackMenu(
              context,
              ref,
              track,
              playlistEntry: playlistId == null ? null : (playlistId, index),
            ),
          ),
        );
      },
    );
  }
}

/// The tracks of [tracks] that can be played now.
List<Track> playableTracks(WidgetRef ref, List<Track> tracks) {
  final missing = ref.read(missingTracksProvider).value ?? const {};
  return [
    for (final t in tracks)
      if (!missing.contains(t.id)) t,
  ];
}
