import 'dart:async';

import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/playback/listening.dart';

/// [ListeningStore] kept in memory: web, fallback, and tests.
final class InMemoryListeningStore implements ListeningStore {
  final _changes = StreamController<List<HistoryEntry>>.broadcast();
  final _history = <HistoryEntry>[];
  SavedSession? _session;

  @override
  Stream<List<HistoryEntry>> watchHistory() async* {
    yield List.unmodifiable(_history);
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> addToHistory(HistoryEntry entry) async {
    _history.insert(0, entry);
    if (_history.length > historyLimit) _history.removeLast();
    _changes.add(List.unmodifiable(_history));
    return const Ok(null);
  }

  @override
  Future<Result<void>> clearHistory() async {
    _history.clear();
    _changes.add(const []);
    return const Ok(null);
  }

  @override
  Future<SavedSession?> loadSession() async => _session;

  @override
  Future<Result<void>> saveSession(SavedSession? session) async {
    _session = session;
    return const Ok(null);
  }
}
