import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';

/// The user's local library: tracks, favorites and playlists.
///
/// Writes return [Result]; a failure means nothing was changed.
abstract interface class LibraryRepository {
  /// The current snapshot first, then one per change.
  Stream<LibrarySnapshot> watch();

  LibrarySnapshot get current;

  /// Adds or replaces tracks by id.
  Future<Result<void>> addTracks(List<Track> tracks);

  /// Removes tracks and their audio files, and drops them from favorites
  /// and playlists.
  Future<Result<void>> removeTracks(Set<TrackId> ids);

  Future<Result<void>> setFavorite(TrackId id, {required bool favorite});

  Future<Result<Playlist>> createPlaylist(String name);

  Future<Result<void>> renamePlaylist(PlaylistId id, String name);

  Future<Result<void>> deletePlaylist(PlaylistId id);

  Future<Result<void>> addToPlaylist(PlaylistId id, List<TrackId> trackIds);

  /// Removes the entry at [index] (a track may appear more than once).
  Future<Result<void>> removeFromPlaylist(PlaylistId id, int index);
}

/// Library-level validation shared by all implementations.
abstract final class PlaylistRules {
  static const maxNameLength = 100;

  /// The trimmed name, or null when it is empty or too long.
  static String? validName(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.length > maxNameLength) return null;
    return name;
  }
}
