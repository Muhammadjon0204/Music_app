import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/library/library_providers.dart';
import 'package:music_app/application/online/online_track_lookup.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/core/logging/app_logger.dart';
import 'package:music_app/core/utils/list_equality.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/listening.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Bound at the composition root; null keeps no history (tests).
final listeningStoreProvider = Provider<ListeningStore?>((ref) => null);

/// Listening history, newest first.
final listeningHistoryProvider = StreamProvider<List<HistoryEntry>>((ref) {
  final store = ref.watch(listeningStoreProvider);
  return store?.watchHistory() ?? Stream.value(const []);
}, retry: (_, _) => null);

/// How many recently played tracks are shown.
const recentlyPlayedLimit = 50;

/// Recently played tracks, newest first, each once.
final recentlyPlayedProvider = FutureProvider<ResolvedTracks>((ref) async {
  final history = await ref.watch(listeningHistoryProvider.future);
  final library = await ref.watch(librarySnapshotProvider.future);
  ref.watch(onlineTrackCacheProvider);
  final distinct = <TrackId>{};
  for (final entry in history) {
    distinct.add(entry.trackId);
    if (distinct.length == recentlyPlayedLimit) break;
  }
  return resolveTrackIds(ref, distinct.toList(), library);
}, retry: (_, _) => null);

/// Restores the last session once at startup, then records listening and
/// saves the session as it changes. Read once by the composition root.
final listeningSessionProvider = FutureProvider<void>((ref) async {
  final store = ref.watch(listeningStoreProvider);
  final player = ref.watch(playbackControllerProvider);
  if (store == null || player == null) return;
  final logger = ref.read(appLoggerProvider);

  try {
    await _restore(ref, store, player);
  } on Object catch (e, stackTrace) {
    // A session that cannot be restored is simply not restored.
    logger.warning('Session restore failed', error: e, stackTrace: stackTrace);
  }
  final recorder = ListeningRecorder(
    player: player,
    store: store,
    now: ref.read(clockProvider),
    logger: logger,
  )..start();
  ref.onDispose(recorder.dispose);
}, retry: (_, _) => null);

Future<void> _restore(
  Ref ref,
  ListeningStore store,
  PlaybackController player,
) async {
  final session = await store.loadSession();
  // Something already plays (e.g. the user was quick): leave it alone.
  if (session == null || player.snapshot.currentTrack != null) return;
  // The repository's current state: the snapshot provider may not be
  // listened to yet at startup (Riverpod pauses unlistened providers).
  final library = ref.read(libraryRepositoryProvider).current;
  final resolved = await resolveTrackIds(ref, session.queue, library);
  if (resolved.tracks.isEmpty || player.snapshot.currentTrack != null) return;

  final currentId = session.queue[session.index];
  final index = resolved.tracks.indexWhere((t) => t.id == currentId);
  await player.setRepeatMode(session.repeatMode);
  await player.setQueue(resolved.tracks, startIndex: index < 0 ? 0 : index);
  // Only where the same track is still current; otherwise from its start.
  if (index >= 0 && session.position > Duration.zero) {
    await player.seek(session.position);
  }
}

/// Counts listens into the history and keeps the saved session current.
///
/// A listen counts once per play of a track, after [listenThreshold] (or
/// half of a shorter track), only while sound is really playing. The
/// session (queue by ID, position, repeat) is saved when the queue
/// changes, on pause, and every [positionSaveInterval] while playing.
final class ListeningRecorder {
  ListeningRecorder({
    required this._player,
    required this._store,
    DateTime Function()? now,
    this._logger,
    this.positionSaveInterval = const Duration(seconds: 10),
  }) : _now = now ?? DateTime.now;

  final PlaybackController _player;
  final ListeningStore _store;
  final DateTime Function() _now;
  final AppLogger? _logger;
  final Duration positionSaveInterval;

  StreamSubscription<PlaybackSnapshot>? _snapshots;
  StreamSubscription<Duration>? _positions;

  /// The last snapshot received: position events are matched against it,
  /// not against whatever the controller reports at that moment.
  PlaybackSnapshot _snapshot = PlaybackSnapshot.initial;
  TrackId? _trackId;
  bool _counted = false;
  Duration _lastPosition = Duration.zero;
  Duration? _savedPosition;
  _QueueKey? _savedQueue;

  void start() {
    // The current state is what was just restored (or nothing, e.g. when
    // offline): not saved again, so a failed restore never erases the
    // stored session. Only real changes are saved.
    final snapshot = _snapshot = _player.snapshot;
    _trackId = snapshot.currentTrack?.id;
    _savedQueue = _QueueKey.of(snapshot);
    _savedPosition = _player.position;
    _snapshots = _player.snapshots.listen(_onSnapshot);
    _positions = _player.positions.listen(_onPosition);
  }

  Future<void> dispose() async {
    await _snapshots?.cancel();
    await _positions?.cancel();
  }

  void _onSnapshot(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    final id = snapshot.currentTrack?.id;
    if (id != _trackId) {
      _trackId = id;
      _counted = false;
      _lastPosition = Duration.zero;
    }
    final key = _QueueKey.of(snapshot);
    final paused =
        snapshot.status == PlaybackStatus.paused &&
        _savedPosition != _player.position;
    if (key != _savedQueue || paused) _save(snapshot);
  }

  void _onPosition(Duration position) {
    final snapshot = _snapshot;
    final track = snapshot.currentTrack;
    if (track == null) return;
    // Started over (repeat one, "previous", seek to start): a new listen.
    if (_counted &&
        position < _lastPosition - const Duration(seconds: 5) &&
        position < const Duration(seconds: 2)) {
      _counted = false;
    }
    _lastPosition = position;
    if (!_counted &&
        snapshot.status == PlaybackStatus.playing &&
        position >= _threshold(track)) {
      _counted = true;
      unawaited(
        _store.addToHistory(HistoryEntry(trackId: track.id, playedAt: _now())),
      );
    }
    final saved = _savedPosition;
    if (saved == null || (position - saved).abs() >= positionSaveInterval) {
      _save(snapshot);
    }
  }

  static Duration _threshold(Track track) {
    final duration = track.duration;
    if (duration == null) return listenThreshold;
    final half = duration ~/ 2;
    return half < listenThreshold ? half : listenThreshold;
  }

  void _save(PlaybackSnapshot snapshot) {
    final index = snapshot.currentIndex;
    _savedQueue = _QueueKey.of(snapshot);
    _savedPosition = _player.position;
    final session = index == null
        ? null
        : SavedSession(
            queue: [for (final t in snapshot.queue) t.id],
            index: index,
            position: _player.position,
            repeatMode: snapshot.repeatMode,
          );
    unawaited(
      _store.saveSession(session).then((result) {
        if (result case Err(:final failure)) {
          _logger?.warning('Session not saved: $failure');
        }
      }),
    );
  }
}

/// What makes a different session to save: queue, current track, repeat.
final class _QueueKey {
  _QueueKey(this.ids, this.index, this.repeat);

  factory _QueueKey.of(PlaybackSnapshot s) =>
      _QueueKey([for (final t in s.queue) t.id], s.currentIndex, s.repeatMode);

  final List<TrackId> ids;
  final int? index;
  final PlaybackRepeatMode repeat;

  @override
  bool operator ==(Object other) =>
      other is _QueueKey &&
      other.index == index &&
      other.repeat == repeat &&
      elementsEqual(other.ids, ids);

  @override
  int get hashCode => Object.hash(Object.hashAll(ids), index, repeat);
}
