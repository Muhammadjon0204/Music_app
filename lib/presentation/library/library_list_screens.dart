import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/navigation/app_routes.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';

// Lists rather than grids: names stay readable at the largest text sizes.

const _loading = [
  SliverFillRemaining(child: AuraLoadingState(label: AuraStrings.loading)),
];

class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider).value;
    final albums = library?.albums ?? const [];
    return LibraryPage(
      title: AuraStrings.albums,
      slivers: library == null
          ? _loading
          : albums.isEmpty
          ? const [
              LibraryEmptySliver(
                icon: CupertinoIcons.square_stack,
                title: AuraStrings.albumsEmptyTitle,
                message: AuraStrings.albumsEmptyMessage,
              ),
            ]
          : [
              SliverList.builder(
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return AuraListTile(
                    title: album.title,
                    subtitle: [
                      album.artistName ?? AuraStrings.unknownArtist,
                      if (album.year case final year?) '$year',
                    ].join(' · '),
                    leading: AuraArtwork(
                      size: AuraSizes.artworkListTile,
                      image: artworkImage(ref, album.artworkUri),
                      placeholderSeed: album.title,
                    ),
                    onPressed: () =>
                        openDetail(context, DetailKind.album, album.id.value),
                  );
                },
              ),
            ],
    );
  }
}

class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider).value;
    final artists = library?.artists ?? const [];
    return LibraryPage(
      title: AuraStrings.artists,
      slivers: library == null
          ? _loading
          : artists.isEmpty
          ? const [
              LibraryEmptySliver(
                icon: CupertinoIcons.mic,
                title: AuraStrings.artistsEmptyTitle,
                message: AuraStrings.artistsEmptyMessage,
              ),
            ]
          : [
              SliverList.builder(
                itemCount: artists.length,
                itemBuilder: (context, index) {
                  final artist = artists[index];
                  return AuraListTile(
                    title: artist.name,
                    subtitle: AuraStrings.trackCount(
                      library.artistTracks(artist.id).length,
                    ),
                    leading: AuraArtwork(
                      size: AuraSizes.artworkListTile,
                      shape: AuraArtworkShape.circle,
                      placeholderSeed: artist.name,
                    ),
                    onPressed: () =>
                        openDetail(context, DetailKind.artist, artist.id.value),
                  );
                },
              ),
            ],
    );
  }
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askPlaylistName(
      context,
      title: AuraStrings.newPlaylist,
      confirmLabel: AuraStrings.create,
    );
    if (name == null || !context.mounted) return;
    final result = await ref
        .read(libraryRepositoryProvider)
        .createPlaylist(name);
    if (!context.mounted) return;
    switch (result) {
      case Ok(:final value):
        openDetail(context, DetailKind.playlist, value.id.value);
      case Err(:final failure):
        await showFailure(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider).value;
    final playlists = library?.playlists ?? const [];
    final colors = context.auraColors;
    return LibraryPage(
      title: AuraStrings.playlists,
      slivers: library == null
          ? _loading
          : playlists.isEmpty
          ? [
              LibraryEmptySliver(
                icon: CupertinoIcons.music_note_list,
                title: AuraStrings.playlistsEmptyTitle,
                message: AuraStrings.playlistsEmptyMessage,
                primaryAction: AuraStateAction(
                  label: AuraStrings.newPlaylist,
                  onPressed: () => unawaited(_create(context, ref)),
                ),
              ),
            ]
          : [
              SliverToBoxAdapter(
                child: AuraListTile(
                  title: AuraStrings.newPlaylist,
                  leading: Container(
                    width: AuraSizes.artworkListTile,
                    height: AuraSizes.artworkListTile,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AuraRadii.sm),
                    ),
                    child: Icon(CupertinoIcons.add, color: colors.accentText),
                  ),
                  onPressed: () => unawaited(_create(context, ref)),
                ),
              ),
              SliverList.builder(
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final playlist = playlists[index];
                  return AuraListTile(
                    title: playlist.name,
                    subtitle: AuraStrings.trackCount(
                      library.tracksOf(playlist).length,
                    ),
                    leading: AuraArtwork(
                      size: AuraSizes.artworkListTile,
                      placeholderSeed: playlist.name,
                    ),
                    onPressed: () => openDetail(
                      context,
                      DetailKind.playlist,
                      playlist.id.value,
                    ),
                  );
                },
              ),
            ],
    );
  }
}
