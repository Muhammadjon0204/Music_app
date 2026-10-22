import 'dart:async';

import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';

/// [LibraryRepository] kept only in memory: used on the web (no persistent
/// files), as a fallback when the on-device library cannot be opened, and in
/// widget tests. Behaves like the persistent implementation (shared contract
/// tests) but forgets everything on restart.
final class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository({this._now = DateTime.now});

  final DateTime Function() _now;
  final _changes = StreamController<LibrarySnapshot>.broadcast();

  final _tracks = <TrackId, Track>{};
  final _favorites = <TrackId>[];
  final _playlists = <Playlist>[];
  LibrarySnapshot _current = LibrarySnapshot.empty;
  int _idCounter = 0;

  @override
  LibrarySnapshot get current => _current;

  @override
  Stream<LibrarySnapshot> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> addTracks(List<Track> tracks) async {
    for (final track in tracks) {
      _tracks[track.id] = track;
    }
    return _publish();
  }

  @override
  Future<Result<void>> removeTracks(Set<TrackId> ids) async {
    _tracks.removeWhere((id, _) => ids.contains(id));
    _favorites.removeWhere(ids.contains);
    for (var i = 0; i < _playlists.length; i++) {
      final p = _playlists[i];
      _playlists[i] = Playlist(
        id: p.id,
        name: p.name,
        trackIds: p.trackIds.where((id) => !ids.contains(id)).toList(),
      );
    }
    return _publish();
  }

  @override
  Future<Result<void>> setFavorite(TrackId id, {required bool favorite}) async {
    _favorites.remove(id);
    if (favorite) _favorites.insert(0, id);
    return _publish();
  }

  @override
  Future<Result<Playlist>> createPlaylist(String name) async {
    final valid = PlaylistRules.validName(name);
    if (valid == null) {
      return const Err(
        UnexpectedFailure(debugMessage: 'Invalid playlist name'),
      );
    }
    final playlist = Playlist(
      id: PlaylistId('pl-${_now().microsecondsSinceEpoch}-${_idCounter++}'),
      name: valid,
      trackIds: const [],
    );
    _playlists.add(playlist);
    await _publish();
    return Ok(playlist);
  }

  @override
  Future<Result<void>> renamePlaylist(PlaylistId id, String name) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    final valid = PlaylistRules.validName(name);
    if (index < 0 || valid == null) {
      return const Err(UnexpectedFailure(debugMessage: 'Cannot rename'));
    }
    final p = _playlists[index];
    _playlists[index] = Playlist(id: id, name: valid, trackIds: p.trackIds);
    return _publish();
  }

  @override
  Future<Result<void>> deletePlaylist(PlaylistId id) async {
    _playlists.removeWhere((p) => p.id == id);
    return _publish();
  }

  @override
  Future<Result<void>> addToPlaylist(
    PlaylistId id,
    List<TrackId> trackIds,
  ) async {
    final index = _playlists.indexWhere((p) => p.id == id);
    if (index < 0) {
      return const Err(UnexpectedFailure(debugMessage: 'No such playlist'));
    }
    final p = _playlists[index];
    _playlists[index] = Playlist(
      id: id,
      name: p.name,
      trackIds: [...p.trackIds, ...trackIds],
    );
    return _publish();
  }

  @override
  Future<Result<void>> removeFromPlaylist(PlaylistId id, int index) async {
    final i = _playlists.indexWhere((p) => p.id == id);
    if (i < 0 || index < 0 || index >= _playlists[i].trackIds.length) {
      return const Err(UnexpectedFailure(debugMessage: 'No such entry'));
    }
    final p = _playlists[i];
    _playlists[i] = Playlist(
      id: id,
      name: p.name,
      trackIds: [...p.trackIds]..removeAt(index),
    );
    return _publish();
  }

  Future<Result<void>> _publish() async {
    _current = LibrarySnapshot(
      tracks: _tracks.values.toList(),
      favoriteIds: List.of(_favorites),
      playlists: List.of(_playlists),
    );
    _changes.add(_current);
    return const Ok(null);
  }
}
