import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:music_app/domain/providers/music_provider.dart';

/// Online tracks seen or looked up during this session, by app-wide ID.
///
/// Only references (provider + ID) of online tracks are ever stored on
/// the device; their details live here, in memory, for the session only
/// (Audius API terms §2). IDs a provider no longer knows are remembered as
/// missing so they are not requested again.
final onlineTrackCacheProvider =
    NotifierProvider<OnlineTrackCache, OnlineTracksState>(OnlineTrackCache.new);

final class OnlineTracksState {
  OnlineTracksState({
    Map<TrackId, Track> tracks = const {},
    Set<TrackId> missing = const {},
  }) : tracks = Map.unmodifiable(tracks),
       missing = Set.unmodifiable(missing);

  final Map<TrackId, Track> tracks;
  final Set<TrackId> missing;
}

class OnlineTrackCache extends Notifier<OnlineTracksState> {
  @override
  OnlineTracksState build() => OnlineTracksState();

  /// Keeps details of tracks the app just received (search, popular).
  void remember(Iterable<Track> tracks) {
    final fresh = {
      for (final t in tracks)
        if (providerRefOf(t.id) != null) t.id: t,
    };
    if (fresh.isEmpty) return;
    state = OnlineTracksState(
      tracks: {...state.tracks, ...fresh},
      missing: state.missing.difference(fresh.keys.toSet()),
    );
  }

  /// Looks up the given online tracks that are not known yet, one request
  /// per provider where it supports batches. Local IDs are ignored.
  Future<Result<void>> fetch(Iterable<TrackId> ids) async {
    final registry = ref.read(providerRegistryProvider);
    final byProvider = <ProviderId, List<ExternalTrackId>>{};
    for (final id in ids) {
      if (state.tracks.containsKey(id) || state.missing.contains(id)) continue;
      final parts = providerRefOf(id);
      if (parts == null) continue;
      (byProvider[parts.$1] ??= []).add(parts.$2);
    }

    AppFailure? firstFailure;
    for (final MapEntry(key: providerId, value: externalIds)
        in byProvider.entries) {
      final result = await _lookUp(registry, providerId, externalIds);
      switch (result) {
        case Ok(:final value):
          final found = {for (final t in value) t.id: t};
          final asked = {
            for (final e in externalIds)
              TrackId('${providerId.value}:${e.value}'),
          };
          state = OnlineTracksState(
            tracks: {...state.tracks, ...found},
            missing: {
              ...state.missing,
              ...asked.difference(found.keys.toSet()),
            },
          );
        case Err(:final failure):
          firstFailure ??= failure;
      }
    }
    return firstFailure == null ? const Ok(null) : Err(firstFailure);
  }

  static Future<Result<List<Track>>> _lookUp(
    ProviderRegistry registry,
    ProviderId providerId,
    List<ExternalTrackId> ids,
  ) async {
    if (registry.capability<BatchTrackDetailsProvider>(providerId) case Ok(
      :final value,
    )) {
      return value.tracksByIds(ids);
    }
    final single = registry.capability<TrackDetailsProvider>(providerId);
    switch (single) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final found = <Track>[];
        for (final id in ids) {
          switch (await value.trackDetails(id)) {
            case Ok(value: final track):
              found.add(track);
            case Err(failure: NotFoundFailure()):
              break;
            case Err(:final failure):
              return Err(failure);
          }
        }
        return Ok(found);
    }
  }
}

/// Tracks for stored IDs, in the given order: library tracks directly,
/// online ones through the lookup. [unavailable] counts references that
/// no longer resolve (removed from the library or from the provider).
final class ResolvedTracks {
  ResolvedTracks({
    required List<Track> tracks,
    this.unavailable = 0,
    this.failure,
  }) : tracks = List.unmodifiable(tracks);

  final List<Track> tracks;
  final int unavailable;

  /// Online details could not be loaded (e.g. offline); [tracks] then
  /// holds what could be shown.
  final AppFailure? failure;
}

/// Resolves [ids] against [library] and the online lookup.
Future<ResolvedTracks> resolveTrackIds(
  Ref ref,
  List<TrackId> ids,
  LibrarySnapshot library,
) async {
  final online = [
    for (final id in ids)
      if (!library.contains(id) && providerRefOf(id) != null) id,
  ];
  final cache = ref.read(onlineTrackCacheProvider.notifier);
  final fetched = online.isEmpty ? const Ok(null) : await cache.fetch(online);
  final known = ref.read(onlineTrackCacheProvider).tracks;

  final tracks = <Track>[];
  var unavailable = 0;
  for (final id in ids) {
    final track = library.track(id) ?? known[id];
    if (track != null) {
      tracks.add(track);
    } else if (fetched is Ok) {
      unavailable++;
    }
  }
  return ResolvedTracks(
    tracks: tracks,
    unavailable: unavailable,
    failure: switch (fetched) {
      Err(:final failure) => failure,
      Ok() => null,
    },
  );
}

/// Favorite online tracks (stored as references), resolved for display.
final onlineFavoritesProvider = FutureProvider<ResolvedTracks>((ref) async {
  final library = await ref.watch(librarySnapshotProvider.future);
  // Re-resolve when lookups complete elsewhere.
  ref.watch(onlineTrackCacheProvider);
  return resolveTrackIds(ref, library.onlineFavoriteIds, library);
}, retry: (_, _) => null);

/// A playlist's tracks, library and online alike, in playlist order, each
/// paired with its position in the playlist (a track can appear twice; an
/// online track that is gone leaves its position out).
final playlistTracksProvider = FutureProvider.autoDispose
    .family<PlaylistTracks, PlaylistId>((ref, id) async {
      final library = await ref.watch(librarySnapshotProvider.future);
      ref.watch(onlineTrackCacheProvider);
      final playlist = library.playlist(id);
      if (playlist == null) return PlaylistTracks(entries: const []);
      final resolved = await resolveTrackIds(ref, playlist.trackIds, library);
      final byId = {for (final t in resolved.tracks) t.id: t};
      return PlaylistTracks(
        entries: [
          for (final (index, trackId) in playlist.trackIds.indexed)
            if (byId[trackId] case final track?) (index, track),
        ],
        unavailable: resolved.unavailable,
        failure: resolved.failure,
      );
    }, retry: (_, _) => null);

final class PlaylistTracks {
  PlaylistTracks({
    required List<(int, Track)> entries,
    this.unavailable = 0,
    this.failure,
  }) : entries = List.unmodifiable(entries);

  /// (position in the playlist, track).
  final List<(int, Track)> entries;
  final int unavailable;
  final AppFailure? failure;

  List<Track> get tracks => [for (final (_, t) in entries) t];

  ResolvedTracks get asResolved => ResolvedTracks(
    tracks: tracks,
    unavailable: unavailable,
    failure: failure,
  );
}
