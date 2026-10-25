import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/infrastructure_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/playback/sleep_timer.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';

import '../helpers/fake_providers.dart';
import '../helpers/fakes.dart';

void main() {
  late FakePlaybackController player;
  late ProviderContainer container;
  final now = DateTime(2026, 10, 25, 23);

  PlaybackSnapshot playing(int index) => PlaybackSnapshot(
    queue: [onlineTrack('1'), onlineTrack('2')],
    currentIndex: index,
    status: PlaybackStatus.playing,
  );

  void create({PlaybackSnapshot? snapshot}) {
    player = FakePlaybackController(snapshot ?? playing(0));
    container = ProviderContainer.test(
      overrides: [
        playbackControllerProvider.overrideWithValue(player),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  }

  SleepTimerController timer() => container.read(sleepTimerProvider.notifier);
  SleepTimerState state() => container.read(sleepTimerProvider);

  // testWidgets runs with a fake clock, so timers can be fast-forwarded.
  testWidgets('pauses once the time is up, not before', (tester) async {
    create();
    timer().startFor(const Duration(minutes: 15));
    expect(state().endsAt, now.add(const Duration(minutes: 15)));
    expect(state().isActive, isTrue);

    await tester.pump(const Duration(minutes: 14));
    expect(player.pauseCalls, 0);
    await tester.pump(const Duration(minutes: 1));
    expect(player.pauseCalls, 1);
    expect(state().isActive, isFalse);
  });

  testWidgets('a new choice replaces the old one; cancel stops it', (
    tester,
  ) async {
    create();
    timer()
      ..startFor(const Duration(minutes: 15))
      ..startFor(const Duration(minutes: 30));
    await tester.pump(const Duration(minutes: 20));
    expect(player.pauseCalls, 0);

    timer().cancel();
    await tester.pump(const Duration(hours: 1));
    expect(player.pauseCalls, 0);
    expect(state().isActive, isFalse);
  });

  testWidgets('end of track: pauses when the next track starts', (
    tester,
  ) async {
    create();
    timer().stopAtEndOfTrack();
    expect(state().endOfTrack, isTrue);

    player.emit(playing(0));
    await tester.pump();
    expect(player.pauseCalls, 0);

    player.emit(playing(1));
    await tester.pump();
    expect(player.pauseCalls, 1);
    expect(state().isActive, isFalse);
  });

  testWidgets('end of track: also when the queue finishes', (tester) async {
    create();
    timer().stopAtEndOfTrack();
    player.emit(
      PlaybackSnapshot(
        queue: [onlineTrack('1'), onlineTrack('2')],
        currentIndex: 0,
        status: PlaybackStatus.completed,
      ),
    );
    await tester.pump();
    expect(player.pauseCalls, 1);
  });

  testWidgets('end of track does nothing when nothing plays', (tester) async {
    create(snapshot: PlaybackSnapshot.initial);
    timer().stopAtEndOfTrack();
    expect(state().isActive, isFalse);
  });
}
