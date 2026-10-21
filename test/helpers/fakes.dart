import 'dart:async';

import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/home/home_feed.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_controller.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

/// Records commands; never plays audio.
class FakePlaybackController implements PlaybackController {
  FakePlaybackController(this._snapshot);

  PlaybackSnapshot _snapshot;
  final _updates = StreamController<PlaybackSnapshot>.broadcast();
  int playCalls = 0;
  int pauseCalls = 0;

  void emit(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _updates.add(snapshot);
  }

  @override
  PlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<PlaybackSnapshot> get snapshots => _updates.stream;

  @override
  Stream<Duration> get positions => const Stream.empty();

  @override
  Future<void> play() async => playCalls++;

  @override
  Future<void> pause() async => pauseCalls++;

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  @override
  Future<void> skipToIndex(int index) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}

  @override
  Future<void> dispose() => _updates.close();
}

/// Home feed source whose result the test controls.
class FakeHomeFeedSource implements HomeFeedSource {
  FakeHomeFeedSource(this.respond);

  Future<Result<HomeFeed>> Function() respond;
  int calls = 0;

  @override
  Future<Result<HomeFeed>> load() {
    calls++;
    return respond();
  }
}
