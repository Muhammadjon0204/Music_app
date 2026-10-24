import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/presentation/common/dialogs.dart';
import 'package:music_app/presentation/l10n/aura_strings.dart';

enum _TrackAction {
  playNext,
  playLast,
  favorite,
  unfavorite,
  addToPlaylist,
  removeFromPlaylist,
  removeFromLibrary,
}

/// Actions for a library track. [playlistEntry] adds "remove from playlist"
/// for that playlist position.
Future<void> showTrackMenu(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  (PlaylistId, int)? playlistEntry,
}) async {
  final library = ref.read(libraryRepositoryProvider);
  if (!library.current.contains(track.id)) return;
  final favorite = library.current.isFavorite(track.id);
  final player = ref.read(playbackControllerProvider);

  final action = await showActionSheet<_TrackAction>(
    context,
    title: track.title,
    actions: [
      if (player != null) ...const [
        SheetAction(AuraStrings.playNext, _TrackAction.playNext),
        SheetAction(AuraStrings.playLast, _TrackAction.playLast),
      ],
      favorite
          ? const SheetAction(
              AuraStrings.removeFromFavorites,
              _TrackAction.unfavorite,
            )
          : const SheetAction(
              AuraStrings.addToFavorites,
              _TrackAction.favorite,
            ),
      const SheetAction(AuraStrings.addToPlaylist, _TrackAction.addToPlaylist),
      if (playlistEntry != null)
        const SheetAction(
          AuraStrings.removeFromPlaylist,
          _TrackAction.removeFromPlaylist,
        ),
      const SheetAction(
        AuraStrings.removeFromLibrary,
        _TrackAction.removeFromLibrary,
        destructive: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;

  final Future<Result<void>?> pending = switch (action) {
    _TrackAction.playNext => _queue(() => player!.playNext([track])),
    _TrackAction.playLast => _queue(() => player!.addToQueue([track])),
    _TrackAction.favorite => library.setFavorite(track.id, favorite: true),
    _TrackAction.unfavorite => library.setFavorite(track.id, favorite: false),
    _TrackAction.addToPlaylist => _addToPlaylist(context, library, track),
    _TrackAction.removeFromPlaylist => library.removeFromPlaylist(
      playlistEntry!.$1,
      playlistEntry.$2,
    ),
    _TrackAction.removeFromLibrary => _removeFromLibrary(
      context,
      library,
      track,
    ),
  };
  final result = await pending;
  if (result case Err(:final failure) when context.mounted) {
    await showFailure(context, failure);
  }
}

/// Queue edits cannot fail in a way worth reporting.
Future<Result<void>?> _queue(Future<void> Function() edit) async {
  await edit();
  return null;
}

const _newPlaylist = '';

Future<Result<void>?> _addToPlaylist(
  BuildContext context,
  LibraryRepository library,
  Track track,
) async {
  final choice = await showActionSheet<String>(
    context,
    title: AuraStrings.addToPlaylist,
    actions: [
      const SheetAction(AuraStrings.newPlaylist, _newPlaylist),
      for (final playlist in library.current.playlists)
        SheetAction(playlist.name, playlist.id.value),
    ],
  );
  if (choice == null || !context.mounted) return null;

  if (choice != _newPlaylist) {
    return library.addToPlaylist(PlaylistId(choice), [track.id]);
  }
  final name = await askPlaylistName(
    context,
    title: AuraStrings.newPlaylist,
    confirmLabel: AuraStrings.create,
  );
  if (name == null) return null;
  final created = await library.createPlaylist(name);
  return switch (created) {
    Ok(:final value) => library.addToPlaylist(value.id, [track.id]),
    Err(:final failure) => Err(failure),
  };
}

Future<Result<void>?> _removeFromLibrary(
  BuildContext context,
  LibraryRepository library,
  Track track,
) async {
  final confirmed = await confirmDestructive(
    context,
    title: AuraStrings.removeFromLibrary,
    message: AuraStrings.removeFromLibraryConfirm,
    confirmLabel: AuraStrings.remove,
  );
  if (!confirmed) return null;
  return library.removeTracks({track.id});
}

/// Explains a missing file and offers to remove the track.
Future<void> showMissingTrack(
  BuildContext context,
  WidgetRef ref,
  Track track,
) async {
  final remove = await confirmDestructive(
    context,
    title: AuraStrings.missingFile,
    message: AuraStrings.missingFileMessage,
    confirmLabel: AuraStrings.removeFromLibrary,
  );
  if (!remove) return;
  final result = await ref.read(libraryRepositoryProvider).removeTracks({
    track.id,
  });
  if (result case Err(:final failure) when context.mounted) {
    await showFailure(context, failure);
  }
}
