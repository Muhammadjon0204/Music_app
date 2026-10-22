import 'dart:async';
import 'dart:io';

import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/data/library/library_paths.dart';
import 'package:music_app/data/library/track_record.dart';
import 'package:music_app/domain/library/library_repository.dart';
import 'package:music_app/domain/library/library_snapshot.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/playlist.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/music/track_source.dart';
import 'package:sembast/sembast.dart';

/// [LibraryRepository] on sembast, a single-file document database.
///
/// This class is the only writer, so it keeps the current snapshot in
/// memory and publishes a new one after every committed write.
final class SembastLibraryRepository implements LibraryRepository {
  SembastLibraryRepository._(this._db, this._paths, this._now);

  static const schemaVersion = 1;

  /// Opens (or creates) the library database at [path].
  ///
  /// [paths] is used to delete audio files of removed tracks; without it
  /// (web, tests) only records are removed.
  static Future<SembastLibraryRepository> open({
    required DatabaseFactory factory,
    required String path,
    LibraryPaths? paths,
    DateTime Function() now = DateTime.now,
  }) async {
    final db = await factory.openDatabase(path, version: schemaVersion);
    final repository = SembastLibraryRepository._(db, paths, now);
    await repository._load();
    return repository;
  }

  final Database _db;
  final LibraryPaths? _paths;
  final DateTime Function() _now;

  final _tracks = stringMapStoreFactory.store('tracks');
  final _favorites = stringMapStoreFactory.store('favorites');
  final _playlists = stringMapStoreFactory.store('playlists');

  final _changes = StreamController<LibrarySnapshot>.broadcast();
  LibrarySnapshot _current = LibrarySnapshot.empty;
  int _idCounter = 0;

  /// Records that could not be read at startup (corrupt or from a newer
  /// schema). They are left in place, not deleted.
  int skippedRecords = 0;

  @override
  LibrarySnapshot get current => _current;

  @override
  Stream<LibrarySnapshot> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  Future<void> close() async {
    unawaited(_changes.close());
    await _db.close();
  }

  @override
  Future<Result<void>> addTracks(List<Track> tracks) => _write((txn) async {
    for (final track in tracks) {
      await _tracks.record(track.id.value).put(txn, TrackRecord.toMap(track));
    }
  });

  @override
  Future<Result<void>> removeTracks(Set<TrackId> ids) async {
    final removed = [for (final id in ids) ?_current.track(id)];
    final result = await _write((txn) async {
      for (final id in ids) {
        await _tracks.record(id.value).delete(txn);
        await _favorites.record(id.value).delete(txn);
      }
      for (final playlist in _current.playlists) {
        if (playlist.trackIds.any(ids.contains)) {
          await _putPlaylist(
            txn,
            playlist.id,
            playlist.name,
            playlist.trackIds.where((id) => !ids.contains(id)).toList(),
          );
        }
      }
    });
    if (result is Ok) await _deleteAudioFiles(removed);
    return result;
  }

  /// Strictly increasing timestamp, so items stamped within the same clock
  /// tick still keep their order.
  int _nextStamp() {
    final now = _now().microsecondsSinceEpoch;
    _lastStamp = now > _lastStamp ? now : _lastStamp + 1;
    return _lastStamp;
  }

  int _lastStamp = 0;

  @override
  Future<Result<void>> setFavorite(TrackId id, {required bool favorite}) =>
      _write((txn) async {
        final record = _favorites.record(id.value);
        if (favorite) {
          await record.put(txn, {'at': _nextStamp()});
        } else {
          await record.delete(txn);
        }
      });

  @override
  Future<Result<Playlist>> createPlaylist(String name) async {
    final valid = PlaylistRules.validName(name);
    if (valid == null) {
      return const Err(
        UnexpectedFailure(debugMessage: 'Invalid playlist name'),
      );
    }
    final id = PlaylistId(
      'pl-${_now().microsecondsSinceEpoch}-${_idCounter++}',
    );
    final result = await _write((txn) => _putPlaylist(txn, id, valid, []));
    return switch (result) {
      Ok() => Ok(_current.playlist(id)!),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> renamePlaylist(PlaylistId id, String name) async {
    final playlist = _current.playlist(id);
    final valid = PlaylistRules.validName(name);
    if (playlist == null || valid == null) {
      return const Err(UnexpectedFailure(debugMessage: 'Cannot rename'));
    }
    return _write((txn) => _putPlaylist(txn, id, valid, playlist.trackIds));
  }

  @override
  Future<Result<void>> deletePlaylist(PlaylistId id) =>
      _write((txn) => _playlists.record(id.value).delete(txn));

  @override
  Future<Result<void>> addToPlaylist(
    PlaylistId id,
    List<TrackId> trackIds,
  ) async {
    final playlist = _current.playlist(id);
    if (playlist == null) {
      return const Err(UnexpectedFailure(debugMessage: 'No such playlist'));
    }
    return _write(
      (txn) => _putPlaylist(txn, id, playlist.name, [
        ...playlist.trackIds,
        ...trackIds,
      ]),
    );
  }

  @override
  Future<Result<void>> removeFromPlaylist(PlaylistId id, int index) async {
    final playlist = _current.playlist(id);
    if (playlist == null || index < 0 || index >= playlist.trackIds.length) {
      return const Err(UnexpectedFailure(debugMessage: 'No such entry'));
    }
    final trackIds = [...playlist.trackIds]..removeAt(index);
    return _write((txn) => _putPlaylist(txn, id, playlist.name, trackIds));
  }

  Future<void> _putPlaylist(
    Transaction txn,
    PlaylistId id,
    String name,
    List<TrackId> trackIds,
  ) async {
    final existing = await _playlists.record(id.value).get(txn);
    await _playlists.record(id.value).put(txn, {
      'name': name,
      'trackIds': [for (final t in trackIds) t.value],
      'createdAt': existing?['createdAt'] ?? _nextStamp(),
    });
  }

  /// Runs [action] in a transaction, then republishes the snapshot.
  Future<Result<void>> _write(
    Future<void> Function(Transaction txn) action,
  ) async {
    try {
      await _db.transaction(action);
      await _load();
      return const Ok(null);
    } on Object catch (e, stackTrace) {
      return Err(
        StorageFailure(
          debugMessage: 'Library write failed: $e',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _load() async {
    var skipped = 0;
    final trackRecords = await _tracks.find(_db);
    final tracks = <Track>[];
    for (final record in trackRecords) {
      final track = TrackRecord.fromMap(record.key, record.value);
      if (track == null) {
        skipped++;
      } else {
        tracks.add(track);
      }
    }

    final favoriteRecords = await _favorites.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('at', false)]),
    );

    final playlistRecords = await _playlists.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('createdAt')]),
    );
    final playlists = <Playlist>[];
    for (final record in playlistRecords) {
      final name = record.value['name'];
      final ids = record.value['trackIds'];
      if (name is! String || ids is! List<Object?>) {
        skipped++;
        continue;
      }
      playlists.add(
        Playlist(
          id: PlaylistId(record.key),
          name: name,
          trackIds: [
            for (final id in ids)
              if (id is String) TrackId(id),
          ],
        ),
      );
    }

    skippedRecords = skipped;
    _current = LibrarySnapshot(
      tracks: tracks,
      favoriteIds: [for (final r in favoriteRecords) TrackId(r.key)],
      playlists: playlists,
    );
    if (!_changes.isClosed) _changes.add(_current);
  }

  /// Deletes copied audio of removed tracks. Failures are ignored: the
  /// records are already gone, and a leftover file only wastes space.
  Future<void> _deleteAudioFiles(List<Track> tracks) async {
    final paths = _paths;
    if (paths == null) return;
    for (final track in tracks) {
      for (final source in track.sources) {
        if (source is! LocalFileSource) continue;
        final path = paths.resolve(source.fileReference);
        if (path == null) continue;
        try {
          await File(path).delete();
        } on FileSystemException {
          // Already gone.
        }
      }
    }
  }
}
