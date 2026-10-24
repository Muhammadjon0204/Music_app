import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/artwork_image.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/common/play_tracks.dart';
import 'package:music_app/presentation/design_system/design_system.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';
import 'package:music_app/presentation/library/library_page.dart';
import 'package:music_app/presentation/library/mixed_track_list.dart';
import 'package:music_app/presentation/library/track_list_sliver.dart';
import 'package:music_app/presentation/navigation/detail_navigation.dart';

/// Builds a page from the current library, with a loading page until the
/// library has been read.
class _LibraryBuilder extends ConsumerWidget {
  const _LibraryBuilder({required this.title, required this.builder});

  final String title;
  final Widget Function(LibrarySnapshot library) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(librarySnapshotProvider).value;
    if (library != null) return builder(library);
    return LibraryPage(
      title: title,
      slivers: const [
        SliverFillRemaining(
          child: AuraLoadingState(label: AuraStrings.loading),
        ),
      ],
    );
  }
}

/// "Слушать" and "Перемешать" for a list of tracks.
class PlayShuffleBar extends ConsumerWidget {
  const PlayShuffleBar({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPlayable = playableTracks(ref, tracks).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpacing.screenHorizontal,
        0,
        AuraSpacing.screenHorizontal,
        AuraSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: AuraButton(
              label: AuraStrings.playAll,
              icon: CupertinoIcons.play_fill,
              expand: true,
              onPressed: hasPlayable
                  ? () =>
                        unawaited(playTracks(ref, playableTracks(ref, tracks)))
                  : null,
            ),
          ),
          const SizedBox(width: AuraSpacing.md),
          Expanded(
            child: AuraButton(
              label: AuraStrings.shuffleAll,
              icon: CupertinoIcons.shuffle,
              variant: AuraButtonVariant.secondary,
              expand: true,
              onPressed: hasPlayable
                  ? () => unawaited(
                      shuffleTracks(ref, playableTracks(ref, tracks)),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the sort choice for track lists.
class _SortButton extends ConsumerWidget {
  const _SortButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(trackSortProvider);
    String label(TrackSort sort, String text) =>
        sort == current ? '$text ✓' : text;
    return AuraIconButton(
      icon: CupertinoIcons.arrow_up_arrow_down,
      semanticLabel: AuraStrings.sortBy,
      color: context.auraColors.textSecondary,
      onPressed: () async {
        final sort = await showActionSheet<TrackSort>(
          context,
          title: AuraStrings.sortBy,
          actions: [
            SheetAction(
              label(TrackSort.title, AuraStrings.sortTitle),
              TrackSort.title,
            ),
            SheetAction(
              label(TrackSort.artist, AuraStrings.sortArtist),
              TrackSort.artist,
            ),
            SheetAction(
              label(TrackSort.recentlyAdded, AuraStrings.sortRecent),
              TrackSort.recentlyAdded,
            ),
          ],
        );
        if (sort != null) ref.read(trackSortProvider.notifier).select(sort);
      },
    );
  }
}

List<Widget> _trackSlivers(List<Track> tracks, {PlaylistId? playlistId}) => [
  SliverToBoxAdapter(child: PlayShuffleBar(tracks: tracks)),
  TrackListSliver(tracks: tracks, playlistId: playlistId),
];

class AllTracksScreen extends ConsumerWidget {
  const AllTracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(trackSortProvider);
    return _LibraryBuilder(
      title: AuraStrings.allTracks,
      builder: (library) {
        final tracks = sortTracks(library.tracks, sort);
        return LibraryPage(
          title: AuraStrings.allTracks,
          subtitle: AuraStrings.trackCount(tracks.length),
          trailing: const _SortButton(),
          slivers: tracks.isEmpty
              ? const [
                  LibraryEmptySliver(
                    icon: CupertinoIcons.music_note,
                    title: AuraStrings.libraryEmptyTitle,
                    message: AuraStrings.libraryEmptyMessage,
                  ),
                ]
              : _trackSlivers(tracks),
        );
      },
    );
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryBuilder(
      title: AuraStrings.favorites,
      builder: (library) {
        // Newest favorite first, as stored.
        final tracks = library.favorites;
        final onlineIds = library.onlineFavoriteIds;
        final online = ref.watch(onlineFavoritesProvider);
        return LibraryPage(
          title: AuraStrings.favorites,
          subtitle: AuraStrings.trackCount(tracks.length + onlineIds.length),
          slivers: tracks.isEmpty && onlineIds.isEmpty
              ? const [
                  LibraryEmptySliver(
                    icon: CupertinoIcons.heart,
                    title: AuraStrings.favoritesEmptyTitle,
                    message: AuraStrings.favoritesEmptyMessage,
                  ),
                ]
              : [
                  if (tracks.isNotEmpty) ..._trackSlivers(tracks),
                  // Online favorites are stored as references and looked
                  // up again (the provider's data is not kept).
                  if (onlineIds.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: AuraSpacing.xl,
                          bottom: AuraSpacing.xs,
                        ),
                        child: AuraSectionHeader(title: AuraStrings.online),
                      ),
                    ),
                    if (online.value case final resolved?) ...[
                      MixedTrackListSliver(tracks: resolved.tracks),
                      SliverToBoxAdapter(
                        child: ResolvedListFooter(
                          resolved: resolved,
                          onRetry: () =>
                              ref.invalidate(onlineFavoritesProvider),
                        ),
                      ),
                    ] else
                      const SliverToBoxAdapter(child: LoadingRow()),
                  ],
                ],
        );
      },
    );
  }
}

const _notFound = [
  LibraryEmptySliver(
    icon: CupertinoIcons.question_circle,
    title: AuraStrings.notFoundTitle,
    message: AuraStrings.notFoundMessage,
  ),
];

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.albumId});

  final AlbumId albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryBuilder(
      title: AuraStrings.albums,
      builder: (library) {
        final album = library.album(albumId);
        if (album == null) {
          return const LibraryPage(
            title: AuraStrings.notFoundTitle,
            header: SizedBox.shrink(),
            slivers: _notFound,
          );
        }
        final tracks = library.albumTracks(albumId);
        return LibraryPage(
          title: album.title,
          header: _CollectionHeader(
            title: album.title,
            subtitle: album.artistName ?? AuraStrings.unknownArtist,
            details: [
              if (album.year case final year?) '$year',
              AuraStrings.trackCount(tracks.length),
            ].join(' · '),
            artwork: AuraArtwork(
              size: 200,
              image: artworkImage(ref, album.artworkUri),
              borderRadius: AuraRadii.lg,
              placeholderSeed: album.title,
            ),
            glow: artworkImage(ref, album.artworkUri),
            seed: album.title,
          ),
          slivers: _trackSlivers(tracks),
        );
      },
    );
  }
}

class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artistId});

  final ArtistId artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryBuilder(
      title: AuraStrings.artists,
      builder: (library) {
        final artist = library.artist(artistId);
        if (artist == null) {
          return const LibraryPage(
            title: AuraStrings.notFoundTitle,
            header: SizedBox.shrink(),
            slivers: _notFound,
          );
        }
        final tracks = library.artistTracks(artistId);
        return LibraryPage(
          title: artist.name,
          header: _CollectionHeader(
            title: artist.name,
            subtitle: AuraStrings.trackCount(tracks.length),
            artwork: AuraArtwork(
              size: 160,
              shape: AuraArtworkShape.circle,
              placeholderSeed: artist.name,
            ),
            seed: artist.name,
          ),
          slivers: _trackSlivers(tracks),
        );
      },
    );
  }
}

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final PlaylistId playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _LibraryBuilder(
      title: AuraStrings.playlists,
      builder: (library) {
        final playlist = library.playlist(playlistId);
        if (playlist == null) {
          return const LibraryPage(
            title: AuraStrings.notFoundTitle,
            header: SizedBox.shrink(),
            slivers: _notFound,
          );
        }
        final tracks = library.tracksOf(playlist);
        return LibraryPage(
          title: playlist.name,
          trailing: _PlaylistMenuButton(playlist: playlist),
          header: _CollectionHeader(
            title: playlist.name,
            subtitle: AuraStrings.trackCount(tracks.length),
            artwork: AuraArtwork(
              size: 200,
              borderRadius: AuraRadii.lg,
              placeholderSeed: playlist.name,
            ),
            seed: playlist.name,
          ),
          slivers: tracks.isEmpty
              ? const [
                  LibraryEmptySliver(
                    icon: CupertinoIcons.music_note_list,
                    title: AuraStrings.playlistEmptyTitle,
                    message: AuraStrings.playlistEmptyMessage,
                  ),
                ]
              : _trackSlivers(tracks, playlistId: playlist.id),
        );
      },
    );
  }
}

enum _PlaylistAction { rename, delete }

class _PlaylistMenuButton extends ConsumerWidget {
  const _PlaylistMenuButton({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraIconButton(
      icon: CupertinoIcons.ellipsis_circle,
      semanticLabel: '${AuraStrings.more}: ${playlist.name}',
      color: context.auraColors.textSecondary,
      onPressed: () => unawaited(_open(context, ref)),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final library = ref.read(libraryRepositoryProvider);
    final action = await showActionSheet<_PlaylistAction>(
      context,
      title: playlist.name,
      actions: const [
        SheetAction(AuraStrings.rename, _PlaylistAction.rename),
        SheetAction(
          AuraStrings.deletePlaylist,
          _PlaylistAction.delete,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    final Result<void>? result;
    switch (action) {
      case _PlaylistAction.rename:
        final name = await askPlaylistName(
          context,
          title: AuraStrings.rename,
          confirmLabel: AuraStrings.save,
          initial: playlist.name,
        );
        result = name == null
            ? null
            : await library.renamePlaylist(playlist.id, name);
      case _PlaylistAction.delete:
        final confirmed = await confirmDestructive(
          context,
          title: AuraStrings.deletePlaylist,
          message: AuraStrings.deletePlaylistConfirm,
          confirmLabel: AuraStrings.remove,
        );
        if (!confirmed) return;
        result = await library.deletePlaylist(playlist.id);
        if (result is Ok && context.mounted) goBack(context);
    }
    if (result case Err(:final failure) when context.mounted) {
      await showFailure(context, failure);
    }
  }
}

/// Centered artwork, title and details above an album, artist or playlist,
/// over a soft glow of the artwork's colors.
class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.title,
    required this.subtitle,
    required this.artwork,
    required this.seed,
    this.details,
    this.glow,
  });

  final String title;
  final String subtitle;
  final String? details;
  final Widget artwork;

  /// The cover behind the header, blurred; null uses the placeholder
  /// gradient for [seed].
  final ImageProvider<Object>? glow;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final colors = context.auraColors;
    final text = context.auraText;
    final details = this.details;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Clipped, so the blur does not bleed below the header.
        Positioned.fill(
          child: ClipRect(
            child: Opacity(
              opacity: 0.5,
              child: AuraArtworkBackdrop(
                image: glow,
                placeholderSeed: seed,
                blur: 48,
              ),
            ),
          ),
        ),
        // Fades the glow into the page.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Solid at both edges, so the glow has no visible border.
                colors: [
                  colors.background,
                  colors.background.withValues(alpha: 0.2),
                  colors.background.withValues(alpha: 0.75),
                  colors.background,
                ],
                stops: const [0, 0.3, 0.65, 1],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpacing.screenHorizontal,
            AuraSpacing.sm,
            AuraSpacing.screenHorizontal,
            AuraSpacing.xl,
          ),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AuraRadii.lg),
                  boxShadow: colors.artworkShadow,
                ),
                child: artwork,
              ),
              const SizedBox(height: AuraSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: text.title1,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AuraSpacing.xs),
              Text(
                subtitle,
                style: text.headline.copyWith(color: colors.accentText),
                textAlign: TextAlign.center,
              ),
              if (details != null) ...[
                const SizedBox(height: AuraSpacing.xxs),
                Text(details, style: text.subhead, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
