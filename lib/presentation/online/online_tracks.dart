import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/play_tracks.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_track_tile.dart';

/// The online source of [track], if it has one.
ProviderTrackSource? onlineSourceOf(Track track) =>
    track.sources.whereType<ProviderTrackSource>().firstOrNull;

/// Whether AURA's player should try [track]. Unknown availability is
/// tried: the provider decides when the stream is resolved.
bool canPlayInApp(Track track) {
  final source = onlineSourceOf(track);
  if (source == null) return true;
  return source.availability.canStreamInApp ||
      source.availability == StreamAvailability.unknown;
}

/// Plays [tracks] from [track] — only the ones AURA can stream, so the
/// queue never contains a track that is known not to play. A track that
/// lives only on its provider opens there instead.
Future<void> playOnline(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks,
  Track track,
) async {
  if (!canPlayInApp(track)) return openOriginal(context, ref, track);
  final playable = tracks.where(canPlayInApp).toList();
  await playTracks(ref, playable, index: playable.indexOf(track));
}

/// Opens the track's page at its provider.
Future<void> openOriginal(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final url = onlineSourceOf(track)?.originalUrl;
  final opener = ref.read(externalLinkOpenerProvider);
  final opened = url != null && opener != null && await opener.open(url);
  if (!opened && context.mounted) {
    await showMessage(
      context,
      title: AuraStrings.linkOpenFailed,
      message: AuraStrings.failureFeatureUnavailableMessage,
    );
  }
}

enum _OnlineAction { playNext, playLast, favorite, unfavorite, open }

Future<void> showOnlineTrackMenu(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final player = ref.read(playbackControllerProvider);
  final queueable = player != null && canPlayInApp(track);
  final library = ref.read(libraryRepositoryProvider);
  final favorite = library.current.isFavorite(track.id);
  final action = await showActionSheet<_OnlineAction>(
    context,
    title: track.title,
    actions: [
      if (queueable) ...const [
        SheetAction(AuraStrings.playNext, _OnlineAction.playNext),
        SheetAction(AuraStrings.playLast, _OnlineAction.playLast),
      ],
      // Saved as a reference only; details are looked up when shown.
      if (favorite)
        const SheetAction(
          AuraStrings.removeFromFavorites,
          _OnlineAction.unfavorite,
        )
      else
        const SheetAction(AuraStrings.addToFavorites, _OnlineAction.favorite),
      if (onlineSourceOf(track)?.canOpenExternally ?? false)
        const SheetAction(AuraStrings.openOriginal, _OnlineAction.open),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case _OnlineAction.playNext:
      await player?.playNext([track]);
    case _OnlineAction.playLast:
      await player?.addToQueue([track]);
    case _OnlineAction.favorite || _OnlineAction.unfavorite:
      ref.read(onlineTrackCacheProvider.notifier).remember([track]);
      final result = await library.setFavorite(
        track.id,
        favorite: action == _OnlineAction.favorite,
      );
      if (result case Err(:final failure) when context.mounted) {
        await showFailure(context, failure);
      }
    case _OnlineAction.open:
      await openOriginal(context, ref, track);
    case null:
      break;
  }
}

/// A row for an online track: tap plays it (or opens it at its provider),
/// "more" offers the provider's page.
class OnlineTrackTile extends ConsumerWidget {
  const OnlineTrackTile({super.key, required this.track, required this.list});

  final Track track;

  /// The list the track belongs to: playing it queues this list.
  final List<Track> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(
      playbackSnapshotProvider.select((s) => s.value?.currentTrack?.id),
    );
    final playable = canPlayInApp(track);
    return LibraryTrackTile(
      track: track,
      isCurrent: track.id == currentId,
      unavailableNote: playable ? null : AuraStrings.onlyInOriginal,
      onPressed: () => unawaited(playOnline(context, ref, list, track)),
      onMore: () => unawaited(showOnlineTrackMenu(context, ref, track)),
    );
  }
}
