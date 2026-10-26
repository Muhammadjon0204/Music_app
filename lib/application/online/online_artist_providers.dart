import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// An artist at an online catalog and their most popular tracks.
final class OnlineArtistPage {
  const OnlineArtistPage({required this.artist, required this.tracks});

  final OnlineArtist artist;
  final List<Track> tracks;
}

typedef OnlineArtistKey = (ProviderId provider, ExternalArtistId artist);

/// How many of the artist's tracks the page shows.
const onlineArtistTrackLimit = 50;

/// The artist's details and tracks, asked for together. A failure of either
/// is the page's failure; never retried automatically.
final onlineArtistProvider = FutureProvider.autoDispose
    .family<OnlineArtistPage, OnlineArtistKey>((ref, key) async {
      final registry = ref.watch(providerRegistryProvider);
      final provider = switch (registry.capability<ArtistProvider>(key.$1)) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      final (artist, tracks) = await (
        provider.artist(key.$2),
        provider.artistTracks(
          key.$2,
          page: const PageRequest(limit: onlineArtistTrackLimit),
        ),
      ).wait;
      final details = switch (artist) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
      final items = switch (tracks) {
        Ok(:final value) => value.items,
        Err(:final failure) => throw failure,
      };
      ref.read(onlineTrackCacheProvider.notifier).remember(items);
      return OnlineArtistPage(artist: details, tracks: items);
    }, retry: (_, _) => null);

/// The catalog artist of an online [track], if its catalog has artist pages.
OnlineArtistKey? onlineArtistOf(ProviderRegistry registry, Track track) {
  final parts = providerRefOf(track.id);
  if (parts == null) return null;
  final source = track.sources.whereType<ProviderTrackSource>().firstOrNull;
  final artistId = source?.artistExternalId;
  if (artistId == null) return null;
  return switch (registry.capability<ArtistProvider>(parts.$1)) {
    Ok() => (parts.$1, artistId),
    Err() => null,
  };
}

/// Tracks like [seed] from its own catalog, for "radio".
Future<Result<List<Track>>> radioTracksFor(
  ProviderRegistry registry,
  Track seed, {
  int limit = 30,
}) async {
  final parts = providerRefOf(seed.id);
  if (parts == null) {
    return const Err(
      FeatureUnavailableFailure(debugMessage: 'Radio needs an online track'),
    );
  }
  return switch (registry.capability<RadioProvider>(parts.$1)) {
    Ok(:final value) => value.radioFor(seed, limit: limit),
    Err(:final failure) => Err(failure),
  };
}
