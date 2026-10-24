import 'dart:async';

import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:sembast/sembast.dart';

/// Listening history and the last session, in the library's database file
/// (two extra stores; the library records are untouched, so no migration
/// is needed). Only track IDs are stored, never metadata of online tracks.
final class SembastListeningStore implements ListeningStore {
  SembastListeningStore(this._db);

  final Database _db;
  final _history = intMapStoreFactory.store('history');
  final _session = stringMapStoreFactory.store('session');
  static const _sessionKey = 'last';

  @override
  Stream<List<HistoryEntry>> watchHistory() => _history
      .query(finder: Finder(sortOrders: [SortOrder(Field.key, false)]))
      .onSnapshots(_db)
      .map((records) => [for (final r in records) ?_entry(r.value)]);

  @override
  Future<Result<void>> addToHistory(HistoryEntry entry) => _guard(() async {
    await _db.transaction((txn) async {
      await _history.add(txn, {
        'id': entry.trackId.value,
        'at': entry.playedAt.millisecondsSinceEpoch,
      });
      final count = await _history.count(txn);
      if (count > historyLimit) {
        final oldest = await _history.findKeys(
          txn,
          finder: Finder(
            sortOrders: [SortOrder(Field.key)],
            limit: count - historyLimit,
          ),
        );
        await _history.records(oldest).delete(txn);
      }
    });
  });

  @override
  Future<Result<void>> clearHistory() =>
      _guard(() async => _history.delete(_db));

  @override
  Future<SavedSession?> loadSession() async {
    try {
      final map = await _session.record(_sessionKey).get(_db);
      return map == null ? null : _sessionFrom(map);
    } on Object {
      return null;
    }
  }

  @override
  Future<Result<void>> saveSession(SavedSession? session) => _guard(() async {
    final record = _session.record(_sessionKey);
    if (session == null) {
      await record.delete(_db);
    } else {
      await record.put(_db, {
        'queue': [for (final id in session.queue) id.value],
        'index': session.index,
        'positionMs': session.position.inMilliseconds,
        'repeat': session.repeatMode.name,
      });
    }
  });

  static HistoryEntry? _entry(Map<String, Object?> map) {
    final id = map['id'];
    final at = map['at'];
    if (id is! String || id.isEmpty || at is! int) return null;
    return HistoryEntry(
      trackId: TrackId(id),
      playedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  /// Null when the stored session is unusable: a broken session is simply
  /// not restored.
  static SavedSession? _sessionFrom(Map<String, Object?> map) {
    final queue = map['queue'];
    final index = map['index'];
    final position = map['positionMs'];
    if (queue is! List<Object?> || index is! int) return null;
    final ids = [
      for (final id in queue)
        if (id is String && id.isNotEmpty) TrackId(id),
    ];
    if (ids.isEmpty || index < 0 || index >= ids.length) return null;
    return SavedSession(
      queue: ids,
      index: index,
      position: position is int && position > 0
          ? Duration(milliseconds: position)
          : Duration.zero,
      repeatMode:
          PlaybackRepeatMode.values.asNameMap()[map['repeat']] ??
          PlaybackRepeatMode.off,
    );
  }

  static Future<Result<void>> _guard(Future<void> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } on Object catch (e, stackTrace) {
      return Err(
        StorageFailure(
          debugMessage: 'Listening store: $e',
          cause: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
