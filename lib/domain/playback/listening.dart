import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/ids.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// One listen: which track, and when it had played long enough to count.
final class HistoryEntry {
  const HistoryEntry({required this.trackId, required this.playedAt});

  final TrackId trackId;
  final DateTime playedAt;

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry &&
      other.trackId == trackId &&
      other.playedAt == playedAt;

  @override
  int get hashCode => Object.hash(trackId, playedAt);
}

/// What was playing when the app was last used, by reference only: online
/// tracks are looked up again on restore (their metadata is never stored).
final class SavedSession {
  SavedSession({
    required List<TrackId> queue,
    required this.index,
    this.position = Duration.zero,
    this.repeatMode = PlaybackRepeatMode.off,
  }) : queue = List.unmodifiable(queue);

  /// Tracks in play order.
  final List<TrackId> queue;
  final int index;
  final Duration position;
  final PlaybackRepeatMode repeatMode;
}

/// Listening history and the last playback session, kept on the device.
abstract interface class ListeningStore {
  /// Newest first.
  Stream<List<HistoryEntry>> watchHistory();

  Future<Result<void>> addToHistory(HistoryEntry entry);

  Future<Result<void>> clearHistory();

  Future<SavedSession?> loadSession();

  /// Null clears the saved session.
  Future<Result<void>> saveSession(SavedSession? session);
}

/// History keeps this many listens; older ones are dropped.
const historyLimit = 500;

/// A track counts as listened once it has played this long (or half of a
/// shorter track), like most music apps.
const listenThreshold = Duration(seconds: 30);
