import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/application/online/online_providers.dart';
import 'package:music_app/application/playback/playback_providers.dart';
import 'package:music_app/application/playback/radio.dart';
import 'package:music_app/core/error/app_failure.dart';
import 'package:music_app/core/error/result.dart';
import 'package:music_app/domain/music/track.dart';
import 'package:music_app/domain/playback/playback_snapshot.dart';
import 'package:music_app/domain/providers/music_provider.dart';

import '../helpers/fake_providers.dart';
import '../helpers/fakes.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeArtistCatalog catalog;
  late FakePlaybackController player;
  late ProviderContainer container;
  final seed = artistTrack('seed');

  setUp(() {
    catalog = FakeArtistCatalog();
    player = FakePlaybackController(PlaybackSnapshot.initial);
    container = ProviderContainer.test(
      overrides: [
        providerRegistryProvider.overrideWithValue(ProviderRegistry([catalog])),
        playbackControllerProvider.overrideWithValue(player),
      ],
    );
  });

  RadioController radio() => container.read(radioProvider.notifier);

  PlaybackSnapshot playing(List<Track> queue, int index) => PlaybackSnapshot(
    queue: queue,
    currentIndex: index,
    status: PlaybackStatus.playing,
  );

  test('starts with the seed, then tracks like it', () async {
    final result = await radio().start(seed);
    expect(result, isA<Ok<void>>());
    expect(catalog.radioSeeds.single, seed);
    expect(player.lastQueue!.first, seed);
    expect(player.lastQueue, hasLength(6));
    expect(player.playCalls, 1);
    expect(container.read(radioProvider)!.seed, seed);
  });

  test('near the end, more tracks are added (each once)', () async {
    await radio().start(seed);
    final queue = player.lastQueue!;
    player.emit(playing(queue, 1));
    await _settle();
    expect(catalog.radioSeeds, hasLength(1));

    // Three left after the current one: time to refill.
    player.emit(playing(queue, queue.length - 4));
    await _settle();
    await _settle();
    expect(catalog.radioSeeds.last, queue[queue.length - 4]);
    expect(player.queueEdits.single, startsWith('add:'));
  });

  test('playing something else ends the radio', () async {
    await radio().start(seed);
    player.emit(playing([onlineTrack('other')], 0));
    await _settle();
    expect(container.read(radioProvider), isNull);
  });

  test('a failure is returned and playback is left alone', () async {
    catalog.radioAnswer = (_) async => const Err(NetworkFailure());
    final result = await radio().start(seed);
    expect((result as Err).failure, isA<NetworkFailure>());
    expect(player.lastQueue, isNull);
    expect(container.read(radioProvider), isNull);

    catalog.radioAnswer = (_) async => const Ok([]);
    final empty = await radio().start(seed);
    expect((empty as Err).failure, isA<NotFoundFailure>());
  });
}
