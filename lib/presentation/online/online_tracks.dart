import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_providers.dart';
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

/// The provider's display name for [track] ("Audius").
String providerNameOf(WidgetRef ref, Track track) {
  final source = onlineSourceOf(track);
  if (source == null) return '';
  return ref.read(providerRegistryProvider)[source.providerId]?.displayName ??
      source.providerId.value;
}

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

Future<void> showOnlineTrackMenu(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final name = providerNameOf(ref, track);
  final open = await showActionSheet<bool>(
    context,
    title: track.title,
    actions: [
      if (onlineSourceOf(track)?.canOpenExternally ?? false)
        SheetAction(AuraStrings.openIn(name), true),
    ],
  );
  if ((open ?? false) && context.mounted) {
    await openOriginal(context, ref, track);
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
      unavailableNote: playable
          ? null
          : AuraStrings.onlyIn(providerNameOf(ref, track)),
      onPressed: () => unawaited(playOnline(context, ref, list, track)),
      onMore: () => unawaited(showOnlineTrackMenu(context, ref, track)),
    );
  }
}
